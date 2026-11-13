import SwiftUI

/// A small strip in the main window: shows the yt-dlp version and updates it in one click.
struct YtdlpUpdateView: View {
    var onShowDetails: () -> Void

    @State private var deps = DependencyManager.shared
    @State private var manager = DownloadManager.shared
    @ObservedObject private var settings = AppSettings.shared

    private var palette: Palette { settings.theme.palette }

    var body: some View {
        HStack(spacing: 6) {
            if deps.isUpdatingYtdlp {
                ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                Text(deps.installLog.last ?? "Updating yt-dlp…")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(palette.text(0.6))
            } else {
                statusText
                Button(buttonTitle) {
                    Task { await deps.updateYtdlp() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(deps.ytdlpUpdateAvailable ? palette.accent : palette.text(0.6))
                .fontWeight(deps.ytdlpUpdateAvailable ? .semibold : .regular)
                .disabled(deps.isInstalling || manager.hasActive)
                .help(manager.hasActive ? "Wait for the current download to finish before updating." : "Update yt-dlp now")
                .accessibilityLabel("Update yt-dlp")

                if deps.ytdlpUpdateFailed {
                    Button("Details", action: onShowDetails)
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.accent)
                        .accessibilityLabel("Show update details in settings")
                }
            }
        }
        .font(.caption)
        .task { await deps.checkYtdlpLatest() }
    }

    private var buttonTitle: String {
        if case .missing = deps.ytdlp { return "Install yt-dlp" }
        return deps.ytdlpUpdateAvailable ? "Update" : "Check for update"
    }

    @ViewBuilder
    private var statusText: some View {
        if let message = deps.ytdlpUpdateMessage {
            Text(message)
                .foregroundStyle(deps.ytdlpUpdateFailed ? palette.error : palette.text(0.6))
        } else if case .missing = deps.ytdlp {
            Text("yt-dlp not found").foregroundStyle(palette.error)
        } else if let installed = deps.ytdlpInstalledVersion {
            if deps.ytdlpUpdateAvailable, let latest = deps.ytdlpLatest {
                Text("yt-dlp \(installed) → \(latest) available")
                    .foregroundStyle(palette.text(0.8))
            } else {
                Text("yt-dlp \(installed)")
                    .foregroundStyle(palette.text(0.6))
            }
        }
    }
}
