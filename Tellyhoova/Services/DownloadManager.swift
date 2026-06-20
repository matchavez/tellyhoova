import Foundation
import UserNotifications
import AppKit

@Observable
@MainActor
final class DownloadManager {
    var queue: [DownloadItem] = []
    private(set) var activeItem: DownloadItem?
    private var activeProcess: Process?
    private var isProcessing = false

    static let shared = DownloadManager()
    private init() {}

    func enqueue(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = DownloadItem(url: trimmed)
        queue.append(item)
        processNextIfIdle()
    }

    func cancel(item: DownloadItem) {
        if activeItem?.id == item.id {
            activeProcess?.terminate()
        } else {
            item.status = .cancelled
            item.statusText = "Cancelled"
        }
    }

    func cancelAll() {
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

    func checkPlaylist(url: String) async -> Int? {
        let settings = AppSettings.shared
        guard settings.ytdlpExists else { return nil }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: settings.ytdlpPath)
            process.arguments = [
                "--flat-playlist",
                "--print", "%(playlist_count)s",
                "--playlist-items", "1",
                "--no-warnings",
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
            try? process.run()
        }
    }

    // MARK: - Download

    private func processNextIfIdle() {
        guard !isProcessing else { return }
        guard let next = queue.first(where: { if case .queued = $0.status { return true }; return false }) else { return }
        Task { await download(next) }
    }

    private func download(_ item: DownloadItem) async {
        isProcessing = true
        activeItem = item

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

        var args = buildArgs(for: item, outputFolder: outputFolder, settings: settings)
        item.appendLog("$ yt-dlp \(args.joined(separator: " "))")

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

        outHandle.readabilityHandler = { [weak item] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                for l in chunk.components(separatedBy: "\n") where !l.isEmpty {
                    // A [download] xx% line updates progress/statusText only.
                    // Keeping it out of the log is what stops the unbounded
                    // array growth and the layout/accessibility storm.
                    let isProgress = l.contains("[download]") && l.contains("%")
                    Self.parseProgress(line: l, into: item)
                    if !isProgress {
                        item?.appendLog(l)
                    }
                }
            }
        }

        errHandle.readabilityHandler = { [weak item] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                for l in chunk.components(separatedBy: "\n") where !l.isEmpty {
                    item?.appendLog("[err] \(l)")
                }
            }
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in
                DispatchQueue.main.async { continuation.resume() }
            }
            do {
                try process.run()
            } catch {
                DispatchQueue.main.async {
                    item.status = .failed(error.localizedDescription)
                    item.statusText = "Launch failed"
                    continuation.resume()
                }
            }
        }

        outHandle.readabilityHandler = nil
        errHandle.readabilityHandler = nil

        if process.terminationStatus == 0 {
            item.status = .completed
            item.progress = 1.0
            item.statusText = "Done"
            if settings.notificationsEnabled {
                notify(title: "Download complete", body: item.filename ?? item.displayURL)
            }
        } else if case .cancelled = item.status {
            // already set
        } else {
            let errMsg = item.log.last(where: { $0.hasPrefix("[err] ERROR") }) ?? "Exit code \(process.terminationStatus)"
            item.status = .failed(errMsg)
            item.statusText = "Failed"
        }

        finish(item: item)
    }

    private func finish(item: DownloadItem) {
        activeItem = nil
        activeProcess = nil
        isProcessing = false
        processNextIfIdle()
    }

    private func buildArgs(for item: DownloadItem, outputFolder: URL, settings: AppSettings) -> [String] {
        var args: [String] = []

        args += ["-f", settings.resolvedFormat]
        args += ["-o", outputFolder.appendingPathComponent(settings.outputTemplate).path]
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
        } else {
            args += ["--merge-output-format", "mp4"]
        }

        args.append(item.url)
        return args
    }

    private static func parseProgress(line: String, into item: DownloadItem?) {
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
