import XCTest
@testable import Tellyhoova

/// Exercises DownloadManager.buildArgs — the function that turns the user's
/// preset and settings into the exact yt-dlp argument vector. This is the
/// core of the app, so the tests below pin the argument contract.
@MainActor
final class BuildArgsTests: XCTestCase {

    private let manager = DownloadManager.shared
    private let outputFolder = URL(fileURLWithPath: "/tmp/tellyhoova-tests")
    private let testURL = "https://example.com/watch?v=abc123"

    // AppSettings is a shared singleton backed by UserDefaults. Snapshot the
    // fields the tests mutate, force a known baseline, restore afterwards so
    // the run never leaves a footprint in the real defaults.
    private var snapshot: [String: Any] = [:]

    override func setUp() async throws {
        try await super.setUp()
        let s = AppSettings.shared
        snapshot = [
            "formatPreset": s.formatPreset,
            "customFormat": s.customFormat,
            "embedMetadata": s.embedMetadata,
            "embedThumbnail": s.embedThumbnail,
            "writeSubtitles": s.writeSubtitles,
            "subtitleLanguages": s.subtitleLanguages,
            "autoSubtitles": s.autoSubtitles,
            "rateLimit": s.rateLimit,
            "retries": s.retries,
            "outputTemplate": s.outputTemplate,
            "sponsorblockRemove": s.sponsorblockRemove,
            "concurrentFragments": s.concurrentFragments,
            "audioBitrate": s.audioBitrate,
        ]
        // Neutral baseline: nothing optional switched on.
        s.formatPreset = .bestQuality
        s.customFormat = "bv*+ba/b"
        s.embedMetadata = false
        s.embedThumbnail = false
        s.writeSubtitles = false
        s.subtitleLanguages = "en"
        s.autoSubtitles = false
        s.rateLimit = ""
        s.retries = 10
        s.outputTemplate = "%(title)s.%(ext)s"
        s.sponsorblockRemove = false
        s.concurrentFragments = 1
        s.audioBitrate = .k256
    }

    override func tearDown() async throws {
        let s = AppSettings.shared
        s.formatPreset = snapshot["formatPreset"] as! FormatPreset
        s.customFormat = snapshot["customFormat"] as! String
        s.embedMetadata = snapshot["embedMetadata"] as! Bool
        s.embedThumbnail = snapshot["embedThumbnail"] as! Bool
        s.writeSubtitles = snapshot["writeSubtitles"] as! Bool
        s.subtitleLanguages = snapshot["subtitleLanguages"] as! String
        s.autoSubtitles = snapshot["autoSubtitles"] as! Bool
        s.rateLimit = snapshot["rateLimit"] as! String
        s.retries = snapshot["retries"] as! Int
        s.outputTemplate = snapshot["outputTemplate"] as! String
        s.sponsorblockRemove = snapshot["sponsorblockRemove"] as! Bool
        s.concurrentFragments = snapshot["concurrentFragments"] as! Int
        s.audioBitrate = snapshot["audioBitrate"] as! AudioBitrate
        try await super.tearDown()
    }

    private func args(_ configure: (AppSettings) -> Void = { _ in }) -> [String] {
        configure(AppSettings.shared)
        let item = DownloadItem(url: testURL)
        return manager.buildArgs(for: item, outputFolder: outputFolder, settings: AppSettings.shared)
    }

    /// Returns the value token that follows `flag`, or nil if the flag is absent.
    private func value(after flag: String, in args: [String]) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    // MARK: - Shared shape

    func testAlwaysHasFormatOutputTemplateAndNewline() {
        let a = args()
        XCTAssertEqual(value(after: "-f", in: a), "bv*+ba/b")
        XCTAssertEqual(value(after: "-o", in: a), "/tmp/tellyhoova-tests/%(title)s.%(ext)s")
        XCTAssertTrue(a.contains("--newline"))
    }

    func testURLIsAlwaysTheLastArgument() {
        XCTAssertEqual(args().last, testURL)
        XCTAssertEqual(args({ $0.formatPreset = .audioMP3 }).last, testURL)
    }

    func testCustomPresetUsesCustomFormatString() {
        let a = args {
            $0.formatPreset = .custom
            $0.customFormat = "worstaudio"
        }
        XCTAssertEqual(value(after: "-f", in: a), "worstaudio")
    }

    // MARK: - Video path

    func testVideoPresetMergesToMp4AndDoesNotExtractAudio() {
        let a = args { $0.formatPreset = .best1080p }
        XCTAssertEqual(value(after: "--merge-output-format", in: a), "mp4")
        XCTAssertFalse(a.contains("--extract-audio"))
        XCTAssertFalse(a.contains("--audio-format"))
        XCTAssertEqual(value(after: "-f", in: a), "bv*[height<=1080]+ba/b")
    }

    // MARK: - Audio path

    func testAudioOnlyBestExtractsWithoutForcingAFormat() {
        // Regression guard for the 1.0.4 bug: "Audio Only (best)" must not
        // pass --audio-format (which would trigger an unwanted transcode),
        // and must not add --merge-output-format mp4.
        let a = args { $0.formatPreset = .audioOnly }
        XCTAssertTrue(a.contains("--extract-audio"))
        XCTAssertFalse(a.contains("--audio-format"))
        XCTAssertFalse(a.contains("--audio-quality"))
        XCTAssertFalse(a.contains("--merge-output-format"))
    }

    func testAudioM4AForcesM4AWithSelectedBitrate() {
        let a = args {
            $0.formatPreset = .audioM4A
            $0.audioBitrate = .k320
        }
        XCTAssertTrue(a.contains("--extract-audio"))
        XCTAssertEqual(value(after: "--audio-format", in: a), "m4a")
        XCTAssertEqual(value(after: "--audio-quality", in: a), "320K")
    }

    func testAudioMP3WithV0PassesQualityZero() {
        // Regression guard for 1.0.4/1.0.6: MP3 preset must actually reach
        // yt-dlp as mp3, and V0 must map to "0" not "0K".
        let a = args {
            $0.formatPreset = .audioMP3
            $0.audioBitrate = .vbrV0
        }
        XCTAssertEqual(value(after: "--audio-format", in: a), "mp3")
        XCTAssertEqual(value(after: "--audio-quality", in: a), "0")
    }

    // MARK: - Optional toggles

    func testMetadataAndThumbnailFlags() {
        let off = args()
        XCTAssertFalse(off.contains("--embed-metadata"))
        XCTAssertFalse(off.contains("--embed-thumbnail"))

        let on = args {
            $0.embedMetadata = true
            $0.embedThumbnail = true
        }
        XCTAssertTrue(on.contains("--embed-metadata"))
        XCTAssertTrue(on.contains("--embed-thumbnail"))
    }

    func testSubtitleFlags() {
        let a = args {
            $0.writeSubtitles = true
            $0.subtitleLanguages = "en,mi"
            $0.autoSubtitles = true
        }
        XCTAssertTrue(a.contains("--write-subs"))
        XCTAssertEqual(value(after: "--sub-langs", in: a), "en,mi")
        XCTAssertTrue(a.contains("--write-auto-subs"))
    }

    func testSubtitlesOffOmitsAllSubtitleFlags() {
        let a = args()
        XCTAssertFalse(a.contains("--write-subs"))
        XCTAssertFalse(a.contains("--sub-langs"))
        XCTAssertFalse(a.contains("--write-auto-subs"))
    }

    func testRateLimitOnlyWhenSet() {
        XCTAssertNil(value(after: "-r", in: args()))
        XCTAssertEqual(value(after: "-r", in: args({ $0.rateLimit = "2M" })), "2M")
    }

    func testRetriesOnlyEmittedWhenNotDefaultTen() {
        XCTAssertFalse(args().contains("--retries"))
        XCTAssertEqual(value(after: "--retries", in: args({ $0.retries = 3 })), "3")
    }

    func testSponsorblockFlag() {
        XCTAssertFalse(args().contains("--sponsorblock-remove"))
        XCTAssertEqual(value(after: "--sponsorblock-remove", in: args({ $0.sponsorblockRemove = true })), "all")
    }

    func testConcurrentFragmentsOnlyAboveOne() {
        XCTAssertFalse(args().contains("-N"))
        XCTAssertEqual(value(after: "-N", in: args({ $0.concurrentFragments = 4 })), "4")
    }
}
