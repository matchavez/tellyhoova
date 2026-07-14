import Foundation
import AppKit

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var formatPreset: FormatPreset {
        didSet { UserDefaults.standard.set(formatPreset.rawValue, forKey: "formatPreset") }
    }
    @Published var customFormat: String {
        didSet { UserDefaults.standard.set(customFormat, forKey: "customFormat") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var outputFolderBookmark: Data? {
        didSet { UserDefaults.standard.set(outputFolderBookmark, forKey: "outputFolderBookmark") }
    }
    @Published var ytdlpPath: String {
        didSet { UserDefaults.standard.set(ytdlpPath, forKey: "ytdlpPath") }
    }
    @Published var embedThumbnail: Bool {
        didSet { UserDefaults.standard.set(embedThumbnail, forKey: "embedThumbnail") }
    }
    @Published var embedMetadata: Bool {
        didSet { UserDefaults.standard.set(embedMetadata, forKey: "embedMetadata") }
    }
    @Published var writeSubtitles: Bool {
        didSet { UserDefaults.standard.set(writeSubtitles, forKey: "writeSubtitles") }
    }
    @Published var subtitleLanguages: String {
        didSet { UserDefaults.standard.set(subtitleLanguages, forKey: "subtitleLanguages") }
    }
    @Published var autoSubtitles: Bool {
        didSet { UserDefaults.standard.set(autoSubtitles, forKey: "autoSubtitles") }
    }
    @Published var rateLimit: String {
        didSet { UserDefaults.standard.set(rateLimit, forKey: "rateLimit") }
    }
    @Published var retries: Int {
        didSet { UserDefaults.standard.set(retries, forKey: "retries") }
    }
    @Published var outputTemplate: String {
        didSet { UserDefaults.standard.set(outputTemplate, forKey: "outputTemplate") }
    }
    @Published var sponsorblockRemove: Bool {
        didSet { UserDefaults.standard.set(sponsorblockRemove, forKey: "sponsorblockRemove") }
    }
    @Published var concurrentFragments: Int {
        didSet { UserDefaults.standard.set(concurrentFragments, forKey: "concurrentFragments") }
    }
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }
    @Published var audioBitrate: AudioBitrate {
        didSet { UserDefaults.standard.set(audioBitrate.rawValue, forKey: "audioBitrate") }
    }

    private init() {
        let ud = UserDefaults.standard
        formatPreset = FormatPreset(rawValue: ud.string(forKey: "formatPreset") ?? "") ?? .quicktimeCompatible
        customFormat = ud.string(forKey: "customFormat") ?? "bv[vcodec^=avc][height<=1080]+ba[acodec^=mp4a]/bv[vcodec^=avc]+ba[acodec^=mp4a]/b[ext=mp4]"
        notificationsEnabled = ud.object(forKey: "notificationsEnabled") as? Bool ?? true
        outputFolderBookmark = ud.data(forKey: "outputFolderBookmark")
        ytdlpPath = ud.string(forKey: "ytdlpPath") ?? Self.detectYtdlp()
        embedThumbnail = ud.object(forKey: "embedThumbnail") as? Bool ?? false
        embedMetadata = ud.object(forKey: "embedMetadata") as? Bool ?? true
        writeSubtitles = ud.object(forKey: "writeSubtitles") as? Bool ?? false
        subtitleLanguages = ud.string(forKey: "subtitleLanguages") ?? "en"
        autoSubtitles = ud.object(forKey: "autoSubtitles") as? Bool ?? false
        rateLimit = ud.string(forKey: "rateLimit") ?? ""
        retries = ud.object(forKey: "retries") as? Int ?? 10
        outputTemplate = ud.string(forKey: "outputTemplate") ?? "%(title)s.%(ext)s"
        sponsorblockRemove = ud.object(forKey: "sponsorblockRemove") as? Bool ?? false
        concurrentFragments = ud.object(forKey: "concurrentFragments") as? Int ?? 1
        theme = AppTheme(rawValue: ud.string(forKey: "theme") ?? "") ?? .studioSlate
        audioBitrate = AudioBitrate(rawValue: ud.string(forKey: "audioBitrate") ?? "") ?? .k256
    }

    var resolvedFormat: String {
        formatPreset == .custom ? customFormat : formatPreset.formatString
    }

    var resolvedOutputFolder: URL {
        var stale = false
        if let bookmark = outputFolderBookmark,
           let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
            return url
        }
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
    }

    func setOutputFolder(_ url: URL) {
        let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        outputFolderBookmark = bookmark
    }

    private static func detectYtdlp() -> String {
        let candidates = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/yt-dlp"
    }

    var ytdlpExists: Bool {
        FileManager.default.fileExists(atPath: ytdlpPath)
    }
}
