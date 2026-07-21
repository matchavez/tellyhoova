import Foundation

enum DependencyState: Equatable {
    case checking
    case ok(detail: String?)
    case missing
    case notApplicable(reason: String)
}

enum Dependency: String, CaseIterable, Identifiable {
    case homebrew
    case ytdlp
    case ffmpeg
    case pillow

    var id: String { rawValue }
}

private let dependencySearchPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

@Observable
@MainActor
final class DependencyManager {
    static let shared = DependencyManager()
    private init() {}

    var homebrew: DependencyState = .checking
    var ytdlp: DependencyState = .checking
    var ffmpeg: DependencyState = .checking
    var pillow: DependencyState = .checking

    var isChecking = false
    var isInstalling = false
    var installLog: [String] = []

    var hasIssues: Bool {
        [homebrew, ytdlp, ffmpeg, pillow].contains {
            if case .missing = $0 { return true }
            return false
        }
    }

    // MARK: - Detection

    func checkAll() async {
        isChecking = true
        homebrew = detectStaticExecutable(candidates: ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"])
        ffmpeg = detectStaticExecutable(candidates: ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"])
        ytdlp = await detectYtdlp()
        pillow = await detectPillow()
        isChecking = false
    }

    private func detectStaticExecutable(candidates: [String]) -> DependencyState {
        candidates.contains { FileManager.default.fileExists(atPath: $0) } ? .ok(detail: nil) : .missing
    }

    private func detectYtdlp() async -> DependencyState {
        let settings = AppSettings.shared
        guard settings.ytdlpExists else { return .missing }
        let version = await captureOutput(executable: settings.ytdlpPath, arguments: ["--version"])
        return .ok(detail: version.map { "v\($0)" })
    }

    /// The interpreter yt-dlp's own launcher script is shebang'd to run on —
    /// nil if yt-dlp is a self-contained binary rather than a pip-installed script,
    /// in which case we have no Python to inspect or install Pillow into.
    private func resolveYtdlpInterpreter() -> String? {
        let path = AppSettings.shared.ytdlpPath
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { handle.closeFile() }
        let head = handle.readData(ofLength: 4096)
        guard let text = String(data: head, encoding: .utf8), text.hasPrefix("#!") else { return nil }
        let firstLine = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? text
        let interpreter = firstLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return interpreter.isEmpty ? nil : interpreter
    }

    private func detectPillow() async -> DependencyState {
        guard let interpreter = resolveYtdlpInterpreter(), FileManager.default.fileExists(atPath: interpreter) else {
            return .notApplicable(reason: "yt-dlp isn't a pip-installed script here, so there's no Python to check.")
        }
        let ok = await processSucceeds(executable: interpreter, arguments: ["-c", "import PIL"])
        return ok ? .ok(detail: nil) : .missing
    }

    // MARK: - Install

    func install(_ dependency: Dependency) async {
        guard !isInstalling else { return }
        isInstalling = true
        installLog.removeAll()

        switch dependency {
        case .homebrew:
            appendLog("Homebrew needs an interactive Terminal session to install (it prompts for your password).")
            appendLog("Paste this into Terminal:")
            appendLog(#"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#)
        case .ytdlp:
            await runInstall(executable: brewPath(), arguments: ["install", "yt-dlp"])
        case .ffmpeg:
            await runInstall(executable: brewPath(), arguments: ["install", "ffmpeg"])
        case .pillow:
            if let interpreter = resolveYtdlpInterpreter() {
                await runInstall(executable: interpreter, arguments: ["-m", "pip", "install", "--upgrade", "pillow"])
            } else {
                appendLog("Can't install Pillow: this yt-dlp build has no Python interpreter to install into.")
                appendLog("Try reinstalling yt-dlp via Homebrew, which uses a pip-installed script.")
            }
        }

        isInstalling = false
        await checkAll()
    }

    private func brewPath() -> String {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/brew"
    }

    private func appendLog(_ line: String) {
        installLog.append(line)
    }

    // MARK: - Process helpers

    private func runInstall(executable: String, arguments: [String]) async {
        guard FileManager.default.fileExists(atPath: executable) else {
            appendLog("[err] \(executable) not found. Install Homebrew first: https://brew.sh")
            return
        }

        appendLog("$ \((executable as NSString).lastPathComponent) \(arguments.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = dependencySearchPath
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let outHandle = outPipe.fileHandleForReading
        let errHandle = errPipe.fileHandleForReading

        outHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                for l in chunk.components(separatedBy: "\n") where !l.isEmpty {
                    self?.appendLog(l)
                }
            }
        }
        errHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                for l in chunk.components(separatedBy: "\n") where !l.isEmpty {
                    self?.appendLog(l)
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
                let message = error.localizedDescription
                DispatchQueue.main.async { [weak self] in
                    self?.appendLog("[err] Failed to launch: \(message)")
                    continuation.resume()
                }
            }
        }

        outHandle.readabilityHandler = nil
        errHandle.readabilityHandler = nil

        if process.terminationStatus == 0 {
            appendLog("✓ Done")
        } else {
            appendLog("✗ Exited with code \(process.terminationStatus)")
        }
    }

    private func captureOutput(executable: String, arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = dependencySearchPath
            process.environment = env
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            process.terminationHandler = { proc in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    continuation.resume(returning: (proc.terminationStatus == 0) ? output : nil)
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private func processSucceeds(executable: String, arguments: [String]) async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = dependencySearchPath
            process.environment = env
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            process.terminationHandler = { proc in
                DispatchQueue.main.async {
                    continuation.resume(returning: proc.terminationStatus == 0)
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}
