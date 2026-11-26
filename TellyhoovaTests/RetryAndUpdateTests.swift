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

    func test403IsRetriedOnceOnly() {
        // A 403 for a geo-blocked or members-only video never clears, so do not make
        // the user wait through three countdowns for it.
        XCTAssertEqual(DownloadManager.retryLimit(errorLines: ["ERROR: unable to download video data: HTTP Error 403: Forbidden"]), 1)
        XCTAssertEqual(DownloadManager.retryLimit(errorLines: ["ERROR: HTTP Error 429: Too Many Requests"]), 3)
        XCTAssertEqual(DownloadManager.retryLimit(errorLines: ["ERROR: The read operation timed out"]), 3)
    }

    func test403HintDoesNotPromiseThatUpdatingFixesIt() {
        XCTAssertTrue(DownloadManager.forbiddenHint.contains("may need a newer yt-dlp"))
        XCTAssertFalse(DownloadManager.forbiddenHint.contains("blocked by the site"))
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

@MainActor
final class InstallLaunchFailureTests: XCTestCase {

    func testUpdateWithAnUnlaunchableYtdlpFailsWithoutCrashing() async throws {
        // yt-dlp outside a Homebrew Cellar is updated with "yt-dlp -U", which goes
        // through runInstall. Before the fix this read terminationStatus on a process
        // that never launched.
        let settings = AppSettings.shared
        let savedPath = settings.ytdlpPath
        defer { settings.ytdlpPath = savedPath }
        let path = try makeUnlaunchableExecutable()
        defer { try? FileManager.default.removeItem(atPath: path) }
        settings.ytdlpPath = path

        let deps = DependencyManager.shared
        await deps.updateYtdlp()

        XCTAssertTrue(deps.ytdlpUpdateFailed)
        XCTAssertFalse(deps.isInstalling)
        XCTAssertTrue(deps.installLog.contains { $0.hasPrefix("[err] Failed to launch") })
        XCTAssertFalse(deps.installLog.contains { $0.hasPrefix("✗ Exited with code") })
    }
}

final class YtdlpButtonTests: XCTestCase {

    func testButtonOnlyUpdatesWhenAnUpdateIsKnown() {
        XCTAssertEqual(DependencyManager.ytdlpButtonAction(ytdlpMissing: true, updateAvailable: false), .install)
        XCTAssertEqual(DependencyManager.ytdlpButtonAction(ytdlpMissing: false, updateAvailable: true), .update)
        // "Check for update" must not run brew upgrade or yt-dlp -U.
        XCTAssertEqual(DependencyManager.ytdlpButtonAction(ytdlpMissing: false, updateAvailable: false), .check)
    }

    @MainActor
    func testCheckForUpdateInstallsNothing() async {
        let deps = DependencyManager.shared
        deps.installLog = ["sentinel"]
        await deps.checkForYtdlpUpdate()
        XCTAssertEqual(deps.installLog, ["sentinel"], "no install command ran")
        XCTAssertFalse(deps.isInstalling)
        XCTAssertFalse(deps.isCheckingYtdlpLatest)
        XCTAssertFalse(deps.ytdlpUpdateFailed)
        XCTAssertTrue(deps.ytdlpUpdateMessage != nil || deps.ytdlpUpdateAvailable)
        deps.installLog = []
    }
}

final class UpdateMessageTests: XCTestCase {

    func testSelfUpdateNeverBlamesHomebrew() {
        let r = DependencyManager.updateResult(succeeded: true, usedHomebrew: false,
                                               stillBehindLatest: "2026.11.20", oldVersion: "2026.10.26", newVersion: "2026.10.26")
        XCTAssertFalse(r.message.contains("Homebrew"))
        XCTAssertTrue(r.failed)
    }

    func testHomebrewLagIsNotAFailure() {
        let r = DependencyManager.updateResult(succeeded: true, usedHomebrew: true,
                                               stillBehindLatest: "2026.11.20", oldVersion: "2026.10.26", newVersion: "2026.10.26")
        XCTAssertEqual(r.message, "2026.11.20 is not in Homebrew yet. Try again later.")
        XCTAssertFalse(r.failed)
    }

    func testOtherOutcomes() {
        XCTAssertEqual(DependencyManager.updateResult(succeeded: false, usedHomebrew: true, stillBehindLatest: nil,
                                                      oldVersion: nil, newVersion: nil).message, "Update failed. See details.")
        XCTAssertEqual(DependencyManager.updateResult(succeeded: true, usedHomebrew: false, stillBehindLatest: nil,
                                                      oldVersion: "2026.10.26", newVersion: "2026.11.20").message, "Updated to 2026.11.20.")
        XCTAssertEqual(DependencyManager.updateResult(succeeded: true, usedHomebrew: true, stillBehindLatest: nil,
                                                      oldVersion: "2026.11.20", newVersion: "2026.11.20").message, "Already up to date.")
    }
}

final class OutputLineSplitterTests: XCTestCase {

    func testLineCutAcrossTwoReadsComesOutWhole() {
        var splitter = OutputLineSplitter()
        XCTAssertEqual(splitter.append(Data("[download] Dest".utf8)), [])
        XCTAssertEqual(splitter.append(Data("ination: a.mp4\nERROR: HTT".utf8)), ["[download] Destination: a.mp4"])
        XCTAssertEqual(splitter.append(Data("P Error 403: Forbidden\n".utf8)), ["ERROR: HTTP Error 403: Forbidden"])
        XCTAssertEqual(splitter.finish(), [])
    }

    func testMultiByteCharacterCutAcrossReadsIsKept() {
        // Before the fix, a read that ended inside the two bytes of "ā" failed to decode
        // and the whole chunk was dropped.
        let bytes = Array("ERROR: Māori title\n".utf8)
        let cut = bytes.firstIndex(of: 0xC4)! + 1
        var splitter = OutputLineSplitter()
        XCTAssertEqual(splitter.append(Data(bytes[..<cut])), [])
        XCTAssertEqual(splitter.append(Data(bytes[cut...])), ["ERROR: Māori title"])
    }

    func testSeveralLinesInOneReadAndCarriageReturns() {
        var splitter = OutputLineSplitter()
        XCTAssertEqual(splitter.append(Data("one\r\n\ntwo\nthr".utf8)), ["one", "two"])
        XCTAssertEqual(splitter.finish(), ["thr"])
        XCTAssertEqual(splitter.finish(), [])
    }

    func testInvalidBytesDoNotDropTheLine() {
        var splitter = OutputLineSplitter()
        var data = Data("bad ".utf8)
        data.append(0xFF)
        data.append(contentsOf: Array(" byte\n".utf8))
        let lines = splitter.append(data)
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].hasPrefix("bad "))
        XCTAssertTrue(lines[0].hasSuffix(" byte"))
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
