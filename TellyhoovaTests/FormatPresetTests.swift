import XCTest
@testable import Tellyhoova

final class FormatPresetTests: XCTestCase {

    func testAudioOnlyClassification() {
        XCTAssertTrue(FormatPreset.audioOnly.isAudioOnly)
        XCTAssertTrue(FormatPreset.audioM4A.isAudioOnly)
        XCTAssertTrue(FormatPreset.audioMP3.isAudioOnly)

        XCTAssertFalse(FormatPreset.quicktimeCompatible.isAudioOnly)
        XCTAssertFalse(FormatPreset.bestQuality.isAudioOnly)
        XCTAssertFalse(FormatPreset.best1080p.isAudioOnly)
        XCTAssertFalse(FormatPreset.best720p.isAudioOnly)
        XCTAssertFalse(FormatPreset.best480p.isAudioOnly)
        XCTAssertFalse(FormatPreset.custom.isAudioOnly)
    }

    func testAudioFormatOnlyForcedForM4AAndMP3() {
        XCTAssertEqual(FormatPreset.audioM4A.audioFormat, "m4a")
        XCTAssertEqual(FormatPreset.audioMP3.audioFormat, "mp3")
        // "Audio Only (best)" keeps the source codec, so no forced transcode.
        XCTAssertNil(FormatPreset.audioOnly.audioFormat)
        XCTAssertNil(FormatPreset.bestQuality.audioFormat)
        XCTAssertNil(FormatPreset.custom.audioFormat)
    }

    func testResolutionCapsAppearInFormatString() {
        XCTAssertTrue(FormatPreset.best1080p.formatString.contains("height<=1080"))
        XCTAssertTrue(FormatPreset.best720p.formatString.contains("height<=720"))
        XCTAssertTrue(FormatPreset.best480p.formatString.contains("height<=480"))
    }

    func testQuickTimeCompatiblePrefersAvcAndMp4a() {
        let f = FormatPreset.quicktimeCompatible.formatString
        XCTAssertTrue(f.contains("vcodec^=avc"))
        XCTAssertTrue(f.contains("acodec^=mp4a"))
    }

    func testCustomFormatStringIsEmpty() {
        XCTAssertEqual(FormatPreset.custom.formatString, "")
    }

    func testEveryCaseHasStableRawValueForPersistence() {
        // AppSettings persists the raw value; a rename would silently reset
        // every user's saved preset, so pin them.
        XCTAssertEqual(FormatPreset.quicktimeCompatible.rawValue, "QuickTime Compatible")
        XCTAssertEqual(FormatPreset.bestQuality.rawValue, "Best Quality")
        XCTAssertEqual(FormatPreset.audioMP3.rawValue, "Audio Only (MP3)")
        XCTAssertEqual(FormatPreset.allCases.count, 9)
    }
}

final class AudioBitrateTests: XCTestCase {

    func testYtdlpValueMapping() {
        XCTAssertEqual(AudioBitrate.k128.ytdlpValue, "128K")
        XCTAssertEqual(AudioBitrate.k192.ytdlpValue, "192K")
        XCTAssertEqual(AudioBitrate.k256.ytdlpValue, "256K")
        XCTAssertEqual(AudioBitrate.k320.ytdlpValue, "320K")
        // V0 is LAME's best VBR preset, passed to ffmpeg as -q:a 0.
        XCTAssertEqual(AudioBitrate.vbrV0.ytdlpValue, "0")
    }

    func testAllCasesCovered() {
        XCTAssertEqual(AudioBitrate.allCases.count, 5)
        for rate in AudioBitrate.allCases {
            XCTAssertFalse(rate.ytdlpValue.isEmpty)
        }
    }
}
