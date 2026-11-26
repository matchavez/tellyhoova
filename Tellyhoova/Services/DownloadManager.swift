import Foundation
import UserNotifications
import AppKit

/// Splits a pipe's byte stream into lines. Bytes wait here until their newline arrives,
/// so a line or a multi-byte character (macrons, emoji) cut across two reads is decoded whole.
struct OutputLineSplitter {
    private var pending = Data()

    /// Adds bytes and returns every line they complete, without the newline.
    mutating func append(_ data: Data) -> [String] {
        pending.append(data)
        var lines: [String] = []
        while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
            lines.append(Self.decode(pending[pending.startIndex..<newline]))
            pending.removeSubrange(pending.startIndex...newline)
        }
        return lines.filter { !$0.isEmpty }
    }

    /// Returns the last line when the stream ends without a newline.
    mutating func finish() -> [String] {
        let rest = Self.decode(pending)
        pending.removeAll()
        return rest.isEmpty ? [] : [rest]
    }

    private static func decode(_ data: Data) -> String {
        // Lossy decoding: a bad byte becomes U+FFFD instead of dropping the whole chunk.
        var text = String(decoding: data, as: UTF8.self)
        if text.hasSuffix("\r") { text.removeLast() }
        return text
    }
}

/// One pipe's splitter, shared by the pipe's reader thread and the main actor.
private final class LockedLineSplitter: @unchecked Sendable {
    private let lock = NSLock()
    private var splitter = OutputLineSplitter()

    func append(_ data: Data) -> [String] { lock.withLock { splitter.append(data) } }
    func finish() -> [String] { lock.withLock { splitter.finish() } }
}

@Observable
@MainActor
final class DownloadManager {
    var queue: [DownloadItem] = []
    private(set) var activeItem: DownloadItem?
    private var activeProcess: Process?
    private var isProcessing = false
    private var cancelRequested: Set<UUID> = []

    /// Seconds to wait before each automatic retry. Its length is the retry limit.
    nonisolated static let retryDelays: [Int] = [3, 8, 15]

    static let shared = DownloadManager()
    private init() {}

    func enqueue(_ url: String, noPlaylist: Bool = false) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = DownloadItem(url: trimmed, noPlaylist: noPlaylist)
        guard Self.isAcceptableURL(trimmed) else {
            // Never hand this text to yt-dlp. Show it as a failed row so the user sees why.
            item.status = .failed("Not a web address. Paste a link that starts with http:// or https://.")
            item.statusText = "Not a web address"
            queue.append(item)
            return
        }
        queue.append(item)
        processNextIfIdle()
    }

    /// True only for one http or https address. Text that starts with "-", holds spaces
    /// or uses another scheme is refused, so it can never reach yt-dlp as an option.
    nonisolated static func isAcceptableURL(_ text: String) -> Bool {
        guard !text.isEmpty,
              !text.hasPrefix("-"),
              !text.contains(where: { $0.isWhitespace }),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host(), !host.isEmpty else { return false }
        return true
    }

    func cancel(item: DownloadItem) {
        if activeItem?.id == item.id {
            // Remember the user asked, so the retry loop does not start another attempt.
            cancelRequested.insert(item.id)
            activeProcess?.terminate()
        } else {
            item.status = .cancelled
            item.statusText = "Cancelled"
        }
    }

    func cancelAll() {
        if let activeItem { cancelRequested.insert(activeItem.id) }
        activeProcess?.terminate()
        for item in queue where item.status == .queued {
            item.status = .cancelled
            item.statusText = "Cancelled"
        }
    }

    func remove(item: DownloadItem) {
        guard item.status.isTerminal else { return }
        queue.removeAll { $0.id == item.id }
    }

    func clearCompleted() {
        queue.removeAll { $0.status.isTerminal }
    }

    var hasActive: Bool { activeItem != nil }
    var pendingCount: Int { queue.filter { if case .queued = $0.status { return true }; return false }.count }
    var totalLogLines: Int { queue.reduce(0) { $0 + $1.log.count } }

    // MARK: - Playlist Check

    /// The playlist check gives up after this many seconds and the URL is queued as is.
    static let playlistCheckTimeout: TimeInterval = 20

    func checkPlaylist(url: String) async -> Int? {
        let settings = AppSettings.shared
        guard settings.ytdlpExists, Self.isAcceptableURL(url) else { return nil }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: settings.ytdlpPath)
            process.arguments = [
                "--flat-playlist",
                "--print", "%(playlist_count)s",
                "--playlist-items", "1",
                "--no-warnings",
                "--",
                url
            ]
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = env
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let count = Int(output)
                DispatchQueue.main.async {
                    continuation.resume(returning: (count != nil && count! > 1) ? count : nil)
                }
            }
            do {
                try process.run()
            } catch {
                // The termination handler never fires for a process that did not launch.
                // Resume here, or the spinner stays and Get stays disabled.
                continuation.resume(returning: nil)
                return
            }
            // A stuck check must not block the queue. Stopping it fires the termination
            // handler, which resumes with nil, so the URL is queued as a plain download.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.playlistCheckTimeout))
                if process.isRunning { process.terminate() }
            }
        }
    }

    // MARK: - Download

    /// Starts the next queued item, if any. Called when an install or update ends.
    func resumeQueue() {
        processNextIfIdle()
    }

    private func processNextIfIdle() {
        guard !isProcessing else { return }
        // Never start yt-dlp while Homebrew or yt-dlp -U is replacing it.
        guard !DependencyManager.shared.isInstalling else { return }
        guard let next = queue.first(where: { if case .queued = $0.status { return true }; return false }) else { return }
        // Claim the slot now, not when the Task runs, so a second call before then
        // cannot start the same item again.
        isProcessing = true
        Task { await download(next) }
    }

    private func download(_ item: DownloadItem) async {
        isProcessing = true
        // The item may have been cancelled between being picked and this Task running.
        guard case .queued = item.status else {
            finish(item: item)
            return
        }
        activeItem = item
        defer { cancelRequested.remove(item.id) }

        let settings = AppSettings.shared

        guard settings.ytdlpExists else {
            item.status = .failed("yt-dlp not found at \(settings.ytdlpPath). Install via Homebrew: brew install yt-dlp")
            item.statusText = "yt-dlp missing"
            finish(item: item)
            return
        }

        item.status = .downloading
        item.statusText = "Starting…"

        let outputFolder = settings.resolvedOutputFolder
        _ = outputFolder.startAccessingSecurityScopedResource()
        defer { outputFolder.stopAccessingSecurityScopedResource() }

        let args = buildArgs(for: item, outputFolder: outputFolder, settings: settings)
        item.appendLog("$ yt-dlp \(args.joined(separator: " "))")

        // YouTube sometimes answers a valid request with a random 403 or a timeout.
        // yt-dlp resumes the .part files, so a retry usually succeeds.
        var attempt = 0
        var result = await runYtdlp(item: item, args: args, outputFolder: outputFolder, settings: settings)
        while let code = result.status, code != 0,
              !cancelRequested.contains(item.id),
              attempt < Self.retryLimit(errorLines: result.errorLines),
              Self.isRetryable(errorLines: result.errorLines) {
            let delay = Self.retryDelays[attempt]
            let limit = Self.retryLimit(errorLines: result.errorLines)
            attempt += 1
            item.appendLog("[retry] \(Self.failureSummary(result.errorLines)). Retry \(attempt) of \(limit) in \(delay)s.")
            guard await waitForRetry(item: item, seconds: delay, attempt: attempt, of: limit) else { break }
            item.progress = 0
            item.statusText = "Retrying…"
            result = await runYtdlp(item: item, args: args, outputFolder: outputFolder, settings: settings)
        }

        if let code = result.status {
            if code == 0 {
                item.status = .completed
                item.progress = 1.0
                item.statusText = attempt > 0 ? "Done (after \(attempt) \(attempt == 1 ? "retry" : "retries"))" : "Done"
                if settings.notificationsEnabled {
                    notify(title: "Download complete", body: item.filename ?? item.displayURL)
                }
            } else if cancelRequested.contains(item.id) {
                item.status = .cancelled
                item.statusText = "Cancelled"
            } else {
                let errMsg = result.errorLines.last(where: { $0.hasPrefix("ERROR") }) ?? "Exit code \(code)"
                item.status = .failed(errMsg)
                if Self.suggestsUpdate(errorLines: result.errorLines) {
                    item.statusText = Self.forbiddenHint
                    // Refresh the "latest version" so the update button in the main window lights up.
                    Task { await DependencyManager.shared.checkYtdlpLatest() }
                } else {
                    item.statusText = "Failed"
                }
            }
        }
        // status == nil means yt-dlp never launched. runYtdlp already set the failure.

        finish(item: item)
    }

    private struct RunResult {
        /// nil when the process could not be launched.
        var status: Int32?
        var errorLines: [String]
    }

    /// Collects stderr lines for one attempt. Only touched on the main actor.
    @MainActor
    private final class LineCollector {
        var lines: [String] = []
    }

    private func runYtdlp(item: DownloadItem, args: [String], outputFolder: URL, settings: AppSettings) async -> RunResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: settings.ytdlpPath)
        process.arguments = args
        process.currentDirectoryURL = outputFolder
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        activeProcess = process

        let outHandle = outPipe.fileHandleForReading
        let errHandle = errPipe.fileHandleForReading
        let collector = LineCollector()
        let outLines = LockedLineSplitter()
        let errLines = LockedLineSplitter()

        outHandle.readabilityHandler = { [weak item] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let lines = outLines.append(data)
            guard !lines.isEmpty else { return }
            DispatchQueue.main.async {
                Self.handleOutput(lines, item: item)
            }
        }

        errHandle.readabilityHandler = { [weak item] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let lines = errLines.append(data)
            guard !lines.isEmpty else { return }
            DispatchQueue.main.async {
                Self.handleErrorOutput(lines, item: item, collector: collector)
            }
        }

        var launched = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in
                DispatchQueue.main.async { continuation.resume() }
            }
            do {
                try process.run()
            } catch {
                launched = false
                DispatchQueue.main.async {
                    item.appendLog("[err] Could not start yt-dlp: \(error.localizedDescription)")
                    item.status = .failed(error.localizedDescription)
                    item.statusText = "Launch failed"
                    continuation.resume()
                }
            }
        }

        outHandle.readabilityHandler = nil
        errHandle.readabilityHandler = nil
        activeProcess = nil

        guard launched else { return RunResult(status: nil, errorLines: []) }

        // Lines the reader threads already sent to the main queue must land in the
        // collector before the result is read. The main queue runs blocks in order.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }

        // The termination handler can fire before the last bytes are read. Drain the pipes
        // so the final ERROR line is never missed, then flush any line with no newline.
        if let rest = try? outHandle.readToEnd(), !rest.isEmpty {
            Self.handleOutput(outLines.append(rest), item: item)
        }
        Self.handleOutput(outLines.finish(), item: item)
        if let rest = try? errHandle.readToEnd(), !rest.isEmpty {
            Self.handleErrorOutput(errLines.append(rest), item: item, collector: collector)
        }
        Self.handleErrorOutput(errLines.finish(), item: item, collector: collector)

        return RunResult(status: process.terminationStatus, errorLines: collector.lines)
    }

    private static func handleOutput(_ lines: [String], item: DownloadItem?) {
        for l in lines where !l.isEmpty {
            // A [download] xx% line updates progress/statusText only.
            // Keeping it out of the log is what stops the unbounded
            // array growth and the layout/accessibility storm.
            let isProgress = l.contains("[download]") && l.contains("%")
            parseProgress(line: l, into: item)
            if !isProgress {
                item?.appendLog(l)
            }
        }
    }

    private static func handleErrorOutput(_ lines: [String], item: DownloadItem?, collector: LineCollector) {
        for l in lines where !l.isEmpty {
            item?.appendLog("[err] \(l)")
            collector.lines.append(l)
        }
    }

    /// Counts down the wait before a retry. Returns false if the user cancelled meanwhile.
    private func waitForRetry(item: DownloadItem, seconds: Int, attempt: Int, of limit: Int) async -> Bool {
        for remaining in stride(from: seconds, to: 0, by: -1) {
            if cancelRequested.contains(item.id) { return false }
            item.statusText = "Retry \(attempt) of \(limit) in \(remaining)s…"
            try? await Task.sleep(for: .seconds(1))
        }
        return !cancelRequested.contains(item.id)
    }

    // MARK: - Retry rules

    /// Errors that are usually temporary: a random 403, rate limits, server errors, network drops.
    /// Anything else (private video, no such format, bad URL) fails at once.
    nonisolated static func isRetryable(errorLines: [String]) -> Bool {
        let patterns = [
            #"http error (403|429|5\d\d)"#,
            #"timed out"#,
            #"connection (reset|aborted|refused)"#,
            #"incompleteread"#,
            #"remote end closed"#,
            #"unexpected eof"#,
        ]
        return errorLines.contains { line in
            let lower = line.lowercased()
            return patterns.contains { lower.range(of: $0, options: .regularExpression) != nil }
        }
    }

    /// How many retries these errors get. A 403 can be permanent (geo-blocked or
    /// members-only video), so it gets one retry, not the full three.
    nonisolated static func retryLimit(errorLines: [String]) -> Int {
        suggestsUpdate(errorLines: errorLines) ? 1 : retryDelays.count
    }

    /// Status text after a 403 that did not clear. A newer yt-dlp may help, but it may not.
    nonisolated static let forbiddenHint = "Failed: the site refused (403). It may need a newer yt-dlp."

    /// A 403 that keeps coming back usually means yt-dlp is out of date.
    nonisolated static func suggestsUpdate(errorLines: [String]) -> Bool {
        errorLines.contains { $0.lowercased().contains("http error 403") }
    }

    nonisolated static func failureSummary(_ errorLines: [String]) -> String {
        let line = errorLines.last(where: { $0.hasPrefix("ERROR") }) ?? "Download failed"
        return line.replacingOccurrences(of: "ERROR: ", with: "")
    }

    private func finish(item: DownloadItem) {
        activeItem = nil
        activeProcess = nil
        isProcessing = false
        processNextIfIdle()
    }

    // Non-private for unit testing (@testable import reaches internal, not private).
    func buildArgs(for item: DownloadItem, outputFolder: URL, settings: AppSettings) -> [String] {
        var args: [String] = []

        args += ["-f", settings.resolvedFormat]
        args += ["-o", outputFolder.appendingPathComponent(AppSettings.safeOutputTemplate(settings.outputTemplate)).path]
        args += ["--newline"]

        if settings.embedMetadata { args += ["--embed-metadata"] }
        if settings.embedThumbnail { args += ["--embed-thumbnail"] }
        if settings.writeSubtitles {
            args += ["--write-subs", "--sub-langs", settings.subtitleLanguages]
        }
        if settings.autoSubtitles { args += ["--write-auto-subs"] }
        if !settings.rateLimit.isEmpty { args += ["-r", settings.rateLimit] }
        if settings.retries != 10 { args += ["--retries", "\(settings.retries)"] }
        if settings.sponsorblockRemove { args += ["--sponsorblock-remove", "all"] }
        if settings.concurrentFragments > 1 { args += ["-N", "\(settings.concurrentFragments)"] }
        if settings.formatPreset.isAudioOnly {
            args += ["--extract-audio"]
            if let audioFormat = settings.formatPreset.audioFormat {
                args += ["--audio-format", audioFormat]
                args += ["--audio-quality", settings.audioBitrate.ytdlpValue]
            }
        } else {
            args += ["--merge-output-format", "mp4"]
        }

        if item.noPlaylist { args += ["--no-playlist"] }

        // "--" ends the options, so the URL is never read as one.
        args += ["--", item.url]
        return args
    }

    static func parseProgress(line: String, into item: DownloadItem?) {
        guard let item else { return }

        // [download]  72.3% of    5.23MiB at    1.20MiB/s ETA 00:03
        if line.contains("[download]") && line.contains("%") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            if let pctStr = parts.first(where: { $0.hasSuffix("%") }),
               let pct = Double(pctStr.dropLast()) {
                item.progress = pct / 100.0
                item.statusText = line
                    .replacingOccurrences(of: "[download]", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        } else if line.contains("[download] Destination:") {
            item.filename = line.components(separatedBy: "Destination:").last?.trimmingCharacters(in: .whitespaces)
            item.statusText = "Downloading…"
        } else if line.contains("[Merger]") || line.contains("[ffmpeg]") {
            item.statusText = "Processing…"
        } else if line.contains("has already been downloaded") {
            item.statusText = "Already downloaded"
        }
    }

    private func notify(title: String, body: String) {
        NSSound(named: "Glass")?.play()

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
}
