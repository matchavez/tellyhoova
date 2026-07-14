import Foundation

enum AudioBitrate: String, CaseIterable, Identifiable {
    case k128 = "128 kbps"
    case k192 = "192 kbps"
    case k256 = "256 kbps"
    case k320 = "320 kbps"
    case vbrV0 = "V0 (best VBR)"

    var id: String { rawValue }

    /// yt-dlp --audio-quality value. The kbps cases are a fixed target
    /// bitrate rather than the content-adaptive VBR scale, so output size
    /// is predictable. V0 is LAME's highest-quality VBR preset (~245kbps,
    /// variable) — passed straight through as ffmpeg's -q:a 0.
    var ytdlpValue: String {
        switch self {
        case .k128: return "128K"
        case .k192: return "192K"
        case .k256: return "256K"
        case .k320: return "320K"
        case .vbrV0: return "0"
        }
    }
}
