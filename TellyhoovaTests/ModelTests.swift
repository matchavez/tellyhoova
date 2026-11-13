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

    func testResolvedOutputFolderFallsBackToDownloads() {
        // With no security-scoped bookmark set, it must resolve to ~/Downloads.
        let s = AppSettings.shared
        let bookmark = s.outputFolderBookmark
        defer { s.outputFolderBookmark = bookmark }
        s.outputFolderBookmark = nil
        XCTAssertEqual(s.resolvedOutputFolder.lastPathComponent, "Downloads")
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
