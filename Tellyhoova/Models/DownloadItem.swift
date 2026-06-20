import Foundation
import Observation

enum DownloadStatus: Equatable {
    case queued
    case checkingPlaylist
    case downloading
    case completed
    case failed(String)
    case cancelled

    var label: String {
        switch self {
        case .queued:           return "Queued"
        case .checkingPlaylist: return "Checking…"
        case .downloading:      return "Downloading"
        case .completed:        return "Completed"
        case .failed:           return "Failed"
        case .cancelled:        return "Cancelled"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: return true
        default: return false
        }
    }
}

@Observable
@MainActor
final class DownloadItem: Identifiable {
    let id = UUID()
    let url: String
    var status: DownloadStatus = .queued
    var progress: Double = 0
    var statusText: String = "Waiting…"
    var log: [String] = []
    var isLogExpanded = true
    var filename: String?

    private let maxLogLines = 800

    init(url: String) {
        self.url = url
    }

    // Append a transcript line, trimming in batches so we never retain the
    // whole download's output. Progress ticks must not come through here.
    func appendLog(_ line: String) {
        log.append(line)
        if log.count > maxLogLines + 200 {
            log.removeFirst(log.count - maxLogLines)
        }
    }

    var displayURL: String {
        url.count > 60 ? String(url.prefix(57)) + "…" : url
    }
}
