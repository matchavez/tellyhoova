import Foundation

enum FormatPreset: String, CaseIterable, Identifiable {
    case quicktimeCompatible = "QuickTime Compatible"
    case bestQuality = "Best Quality"
    case best1080p = "Best ≤ 1080p"
    case best720p = "Best ≤ 720p"
    case best480p = "Best ≤ 480p"
    case audioOnly = "Audio Only (best)"
    case audioM4A = "Audio Only (M4A)"
    case audioMP3 = "Audio Only (MP3)"
    case custom = "Custom…"

    var id: String { rawValue }

    var formatString: String {
        switch self {
        case .quicktimeCompatible: return "bv[vcodec^=avc][height<=1080]+ba[acodec^=mp4a]/bv[vcodec^=avc]+ba[acodec^=mp4a]/b[ext=mp4]"
        case .bestQuality: return "bv*+ba/b"
        case .best1080p:   return #"bv*[height<=1080]+ba/b"#
        case .best720p:    return #"bv*[height<=720]+ba/b"#
        case .best480p:    return #"bv*[height<=480]+ba/b"#
        case .audioOnly:   return "bestaudio/best"
        case .audioM4A:    return "bestaudio[ext=m4a]/bestaudio/best"
        case .audioMP3:    return "bestaudio[ext=mp3]/bestaudio/best"
        case .custom:      return ""
        }
    }

    var isAudioOnly: Bool {
        self == .audioOnly || self == .audioM4A || self == .audioMP3
    }

    /// yt-dlp --audio-format value to force a transcode when extracting audio.
    /// nil means keep the source codec as-is (no forced conversion).
    var audioFormat: String? {
        switch self {
        case .audioM4A: return "m4a"
        case .audioMP3: return "mp3"
        default:        return nil
        }
    }
}
