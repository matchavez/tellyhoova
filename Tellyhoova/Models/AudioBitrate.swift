import Foundation

enum AudioBitrate: String, CaseIterable, Identifiable {
    case k128 = "128 kbps"
    case k192 = "192 kbps"
    case k256 = "256 kbps"
    case k320 = "320 kbps"

    var id: String { rawValue }

    /// yt-dlp --audio-quality value: a fixed target bitrate rather than
    /// the content-adaptive VBR scale, so output size is predictable.
    var ytdlpValue: String {
        switch self {
        case .k128: return "128K"
        case .k192: return "192K"
        case .k256: return "256K"
        case .k320: return "320K"
        }
    }
}
