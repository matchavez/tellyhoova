import XCTest
@testable import Tellyhoova

@MainActor
final class DownloadItemTests: XCTestCase {

    func testDisplayURLTruncatesLongURLs() {
        let short = "https://youtu.be/abc"
        XCTAssertEqual(DownloadItem(url: short).displayURL, short)

        let long = "https://www.youtube.com/watch?v=abcdefghijklmnop&list=PLsomeverylongplaylistidentifier12345"
        let shown = DownloadItem(url: long).displayURL
        XCTAssertEqual(shown.count, 58) // 57 chars + ellipsis
        XCTAssertTrue(shown.hasSuffix("\u{2026}"))
    }

    func testAppendLogKeepsTranscriptBounded() {
        let item = DownloadItem(url: "https://youtu.be/x")
        for i in 0..<2_000 {
            item.appendLog("line \(i)")
        }
        // maxLogLines is 800, trimmed once the buffer passes 1000.
        XCTAssertLessThanOrEqual(item.log.count, 1_000)
        XCTAssertGreaterThanOrEqual(item.log.count, 800)
        XCTAssertEqual(item.log.last, "line 1999")
    }

    func testStatusStartsQueued() {
        XCTAssertEqual(DownloadItem(url: "https://youtu.be/x").status, .queued)
    }
}

final class DownloadStatusTests: XCTestCase {

    func testTerminalStates() {
        XCTAssertTrue(DownloadStatus.completed.isTerminal)
        XCTAssertTrue(DownloadStatus.failed("boom").isTerminal)
        XCTAssertTrue(DownloadStatus.cancelled.isTerminal)

        XCTAssertFalse(DownloadStatus.queued.isTerminal)
        XCTAssertFalse(DownloadStatus.checkingPlaylist.isTerminal)
        XCTAssertFalse(DownloadStatus.downloading.isTerminal)
    }

    func testLabels() {
        XCTAssertEqual(DownloadStatus.queued.label, "Queued")
        XCTAssertEqual(DownloadStatus.downloading.label, "Downloading")
        XCTAssertEqual(DownloadStatus.failed("x").label, "Failed")
    }

    func testFailureDetailShowsTheReasonWithoutPrefix() {
        XCTAssertEqual(DownloadStatus.failed("ERROR: [youtube] abc: Private video").failureDetail, "[youtube] abc: Private video")
        XCTAssertEqual(DownloadStatus.failed("Exit code 1").failureDetail, "Exit code 1")
        XCTAssertNil(DownloadStatus.failed("  ").failureDetail)
        XCTAssertNil(DownloadStatus.completed.failureDetail)
        XCTAssertNil(DownloadStatus.downloading.failureDetail)
    }

    func testFailedEqualityComparesMessage() {
        XCTAssertEqual(DownloadStatus.failed("a"), .failed("a"))
        XCTAssertNotEqual(DownloadStatus.failed("a"), .failed("b"))
    }
}

@MainActor
final class AppSettingsTests: XCTestCase {

    func testResolvedFormatUsesPresetStringUnlessCustom() {
        let s = AppSettings.shared
        let preset = s.formatPreset
        let custom = s.customFormat
        defer { s.formatPreset = preset; s.customFormat = custom }

        s.formatPreset = .best720p
        XCTAssertEqual(s.resolvedFormat, FormatPreset.best720p.formatString)

        s.formatPreset = .custom
        s.customFormat = "bv*[height<=360]+ba"
        XCTAssertEqual(s.resolvedFormat, "bv*[height<=360]+ba")
    }

    func testBlankCustomFormatFallsBackToTheDefaultPreset() {
        let s = AppSettings.shared
        let preset = s.formatPreset
        let custom = s.customFormat
        defer { s.formatPreset = preset; s.customFormat = custom }

        s.formatPreset = .custom
        s.customFormat = ""
        XCTAssertEqual(s.resolvedFormat, FormatPreset.quicktimeCompatible.formatString)
        s.customFormat = "   "
        XCTAssertEqual(s.resolvedFormat, FormatPreset.quicktimeCompatible.formatString)
        s.customFormat = "  bestaudio  "
        XCTAssertEqual(s.resolvedFormat, "bestaudio")
    }

    func testResolvedOutputFolderFallsBackToDownloads() {
        // With no security-scoped bookmark set, it must resolve to ~/Downloads.
        let s = AppSettings.shared
        let bookmark = s.outputFolderBookmark
        defer { s.outputFolderBookmark = bookmark }
        s.outputFolderBookmark = nil
        XCTAssertEqual(s.resolvedOutputFolder.lastPathComponent, "Downloads")
    }
}

/// Makes a file with the execute bit set that macOS cannot run (no shebang, not a binary),
/// so Process.run() throws. Used to test launch failures without a real yt-dlp.
func makeUnlaunchableExecutable() throws -> String {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("tellyhoova-unlaunchable-\(UUID().uuidString)").path
    try Data("not a program\n".utf8).write(to: URL(fileURLWithPath: path))
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    return path
}

@MainActor
final class PlaylistCheckTests: XCTestCase {

    private var savedPath = ""

    override func setUp() async throws {
        try await super.setUp()
        savedPath = AppSettings.shared.ytdlpPath
    }

    override func tearDown() async throws {
        AppSettings.shared.ytdlpPath = savedPath
        try await super.tearDown()
    }

    func testYtdlpExistsNeedsAnExecutableFile() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("tellyhoova-plain-\(UUID().uuidString)").path
        try Data("x".utf8).write(to: URL(fileURLWithPath: path))
        defer { try? FileManager.default.removeItem(atPath: path) }

        AppSettings.shared.ytdlpPath = path
        XCTAssertFalse(AppSettings.shared.ytdlpExists, "a file without the execute bit is not usable")

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        XCTAssertTrue(AppSettings.shared.ytdlpExists)
    }

    func testPlaylistCheckReturnsWhenYtdlpCannotLaunch() async throws {
        // Before the fix this await never returned: the continuation was never resumed.
        let path = try makeUnlaunchableExecutable()
        defer { try? FileManager.default.removeItem(atPath: path) }
        AppSettings.shared.ytdlpPath = path

        let count = await DownloadManager.shared.checkPlaylist(url: "https://example.com/watch?v=abc")
        XCTAssertNil(count)
    }

    func testPlaylistCheckHasATimeLimit() {
        XCTAssertGreaterThan(DownloadManager.playlistCheckTimeout, 0)
        XCTAssertLessThanOrEqual(DownloadManager.playlistCheckTimeout, 30)
    }
}

/// Polls on the main actor until the condition is true. Returns false after the time limit.
@MainActor
func waitUntil(seconds: Double = 10, _ condition: () -> Bool) async -> Bool {
    let end = Date().addingTimeInterval(seconds)
    while !condition() {
        if Date() > end { return false }
        try? await Task.sleep(for: .milliseconds(50))
    }
    return true
}

@MainActor
final class LaunchFailureTests: XCTestCase {

    private var savedPath = ""

    override func setUp() async throws {
        try await super.setUp()
        savedPath = AppSettings.shared.ytdlpPath
    }

    override func tearDown() async throws {
        AppSettings.shared.ytdlpPath = savedPath
        try await super.tearDown()
    }

    func testLaunchFailureShowsAReasonAndLogsIt() async throws {
        let path = try makeUnlaunchableExecutable()
        defer { try? FileManager.default.removeItem(atPath: path) }
        AppSettings.shared.ytdlpPath = path

        let manager = DownloadManager.shared
        manager.enqueue("https://example.com/watch?v=launchfail")
        let item = try XCTUnwrap(manager.queue.last)
        defer { manager.remove(item: item) }

        let finished = await waitUntil { item.status.isTerminal }
        XCTAssertTrue(finished)
        XCTAssertEqual(item.statusText, "Launch failed")
        XCTAssertNotNil(item.status.failureDetail)
        XCTAssertTrue(item.log.contains { $0.hasPrefix("[err] Could not start yt-dlp") })
    }

    func testTwoQuickEnqueuesStartEachItemOnce() async throws {
        let path = try makeUnlaunchableExecutable()
        defer { try? FileManager.default.removeItem(atPath: path) }
        AppSettings.shared.ytdlpPath = path

        let manager = DownloadManager.shared
        manager.enqueue("https://example.com/watch?v=first")
        let first = try XCTUnwrap(manager.queue.last)
        manager.enqueue("https://example.com/watch?v=second")
        let second = try XCTUnwrap(manager.queue.last)
        defer { manager.remove(item: first); manager.remove(item: second) }

        let finished = await waitUntil { first.status.isTerminal && second.status.isTerminal }
        XCTAssertTrue(finished)
        // Each item is launched exactly once. Before the fix the first item started twice.
        XCTAssertEqual(first.log.filter { $0.hasPrefix("$ yt-dlp") }.count, 1)
        XCTAssertEqual(second.log.filter { $0.hasPrefix("$ yt-dlp") }.count, 1)
    }

    func testQueueWaitsWhileYtdlpIsBeingInstalled() async throws {
        let path = try makeUnlaunchableExecutable()
        defer { try? FileManager.default.removeItem(atPath: path) }
        AppSettings.shared.ytdlpPath = path

        let deps = DependencyManager.shared
        let manager = DownloadManager.shared
        deps.isInstalling = true
        manager.enqueue("https://example.com/watch?v=waits")
        let item = try XCTUnwrap(manager.queue.last)
        defer {
            deps.isInstalling = false
            if !item.status.isTerminal { manager.cancel(item: item) }
            manager.remove(item: item)
        }

        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(item.status, .queued, "no download starts while an install runs")
        XCTAssertTrue(item.log.isEmpty)

        deps.isInstalling = false
        manager.resumeQueue()
        let finished = await waitUntil { item.status.isTerminal }
        XCTAssertTrue(finished, "the queue starts again when the install ends")
    }

    func testQuittingCancelsQueuedDownloads() throws {
        let deps = DependencyManager.shared
        let manager = DownloadManager.shared
        // Hold the queue still, so the item is still queued when the app quits.
        deps.isInstalling = true
        defer { deps.isInstalling = false }
        manager.enqueue("https://example.com/watch?v=quit")
        let item = try XCTUnwrap(manager.queue.last)
        defer { manager.remove(item: item) }

        AppDelegate().applicationWillTerminate(Notification(name: Notification.Name("TellyhoovaTestQuit")))

        XCTAssertEqual(item.status, .cancelled)
    }

    func testItemCancelledBeforeItStartsIsNotDownloaded() async throws {
        let path = try makeUnlaunchableExecutable()
        defer { try? FileManager.default.removeItem(atPath: path) }
        AppSettings.shared.ytdlpPath = path

        let manager = DownloadManager.shared
        manager.enqueue("https://example.com/watch?v=cancelled")
        let item = try XCTUnwrap(manager.queue.last)
        defer { manager.remove(item: item) }
        manager.cancel(item: item)

        let idle = await waitUntil { !manager.hasActive && manager.pendingCount == 0 }
        XCTAssertTrue(idle)
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(item.status, .cancelled)
        XCTAssertTrue(item.log.isEmpty)
    }
}

@MainActor
final class ProgressParsingTests: XCTestCase {

    func testPercentLineUpdatesProgress() {
        let item = DownloadItem(url: "https://youtu.be/x")
        DownloadManager.parseProgress(line: "[download]  72.3% of 5.23MiB at 1.20MiB/s ETA 00:03", into: item)
        XCTAssertEqual(item.progress, 0.723, accuracy: 0.0001)
    }

    func testCompletePercentLine() {
        let item = DownloadItem(url: "https://youtu.be/x")
        DownloadManager.parseProgress(line: "[download] 100% of 5.23MiB in 00:02", into: item)
        XCTAssertEqual(item.progress, 1.0, accuracy: 0.0001)
    }

    func testDestinationLineSetsFilename() {
        let item = DownloadItem(url: "https://youtu.be/x")
        DownloadManager.parseProgress(line: "[download] Destination: Big Buck Bunny.mp4", into: item)
        XCTAssertEqual(item.filename, "Big Buck Bunny.mp4")
    }

    func testMergerLineSwitchesToProcessing() {
        let item = DownloadItem(url: "https://youtu.be/x")
        DownloadManager.parseProgress(line: "[Merger] Merging formats into \"out.mp4\"", into: item)
        XCTAssertEqual(item.statusText, "Processing\u{2026}")
    }

    func testNonProgressLineLeavesProgressUntouched() {
        let item = DownloadItem(url: "https://youtu.be/x")
        item.progress = 0.4
        DownloadManager.parseProgress(line: "[info] Writing video subtitles to: out.en.vtt", into: item)
        XCTAssertEqual(item.progress, 0.4, accuracy: 0.0001)
    }
}
