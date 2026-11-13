import XCTest
@testable import Tellyhoova

final class RetryRulesTests: XCTestCase {

    func testRetriesOnRandom403() {
        let lines = ["ERROR: unable to download video data: HTTP Error 403: Forbidden"]
        XCTAssertTrue(DownloadManager.isRetryable(errorLines: lines))
    }

    func testRetriesOnRateLimitServerErrorAndTimeout() {
        XCTAssertTrue(DownloadManager.isRetryable(errorLines: ["ERROR: HTTP Error 429: Too Many Requests"]))
        XCTAssertTrue(DownloadManager.isRetryable(errorLines: ["ERROR: HTTP Error 503: Service Unavailable"]))
        XCTAssertTrue(DownloadManager.isRetryable(errorLines: ["ERROR: The read operation timed out"]))
        XCTAssertTrue(DownloadManager.isRetryable(errorLines: ["ERROR: Connection reset by peer"]))
    }

    func testDoesNotRetryPermanentErrors() {
        XCTAssertFalse(DownloadManager.isRetryable(errorLines: ["ERROR: [youtube] abc: Video unavailable"]))
        XCTAssertFalse(DownloadManager.isRetryable(errorLines: ["ERROR: [youtube] abc: Private video. Sign in if you've been granted access"]))
        XCTAssertFalse(DownloadManager.isRetryable(errorLines: ["ERROR: Requested format is not available"]))
        XCTAssertFalse(DownloadManager.isRetryable(errorLines: ["ERROR: HTTP Error 404: Not Found"]))
        XCTAssertFalse(DownloadManager.isRetryable(errorLines: []))
    }

    @MainActor
    func testRetryLimitIsThree() {
        let delays = DownloadManager.retryDelays
        XCTAssertEqual(delays.count, 3)
        XCTAssertEqual(delays, delays.sorted())
    }

    func testOnly403SuggestsUpdatingYtdlp() {
        XCTAssertTrue(DownloadManager.suggestsUpdate(errorLines: ["ERROR: unable to download video data: HTTP Error 403: Forbidden"]))
        XCTAssertFalse(DownloadManager.suggestsUpdate(errorLines: ["ERROR: HTTP Error 429: Too Many Requests"]))
    }

    func testFailureSummaryStripsErrorPrefix() {
        XCTAssertEqual(
            DownloadManager.failureSummary(["[download] x", "ERROR: HTTP Error 403: Forbidden"]),
            "HTTP Error 403: Forbidden"
        )
        XCTAssertEqual(DownloadManager.failureSummary([]), "Download failed")
    }
}

final class VersionCompareTests: XCTestCase {

    func testNewerAcrossMonthsWithAndWithoutPadding() {
        // yt-dlp prints 2026.07.04, Homebrew and GitHub use 2026.7.4.
        XCTAssertTrue(DependencyManager.isVersion("2026.10.26", newerThan: "2026.07.04"))
        XCTAssertTrue(DependencyManager.isVersion("2026.10.26", newerThan: "2026.7.4"))
    }

    func testSameVersionIsNotNewer() {
        XCTAssertFalse(DependencyManager.isVersion("2026.07.04", newerThan: "2026.7.4"))
    }

    func testOlderIsNotNewer() {
        XCTAssertFalse(DependencyManager.isVersion("2026.7.4", newerThan: "2026.10.26"))
    }

    func testPatchSuffixCounts() {
        // yt-dlp sometimes ships a fourth part, e.g. 2026.10.26.1.
        XCTAssertTrue(DependencyManager.isVersion("2026.10.26.1", newerThan: "2026.10.26"))
    }
}
