import SwiftUI
import UserNotifications
import AppKit

struct ContentView: View {
    @State private var urlText = ""
    @State private var showSettings = false
    @State private var showPlaylistConfirm = false
    @State private var pendingPlaylistURL = ""
    @State private var pendingPlaylistCount = 0
    @State private var isCheckingPlaylist = false

    @State private var manager = DownloadManager.shared
    @ObservedObject private var settings = AppSettings.shared

    private var palette: Palette { settings.theme.palette }

    var body: some View {
        VStack(spacing: 0) {
            inputArea
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
            queueArea
        }
        .frame(minWidth: 480, maxWidth: 600, minHeight: 480)
        .background(palette.background)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .confirmationDialog(
            "This URL contains a playlist of \(pendingPlaylistCount) items.",
            isPresented: $showPlaylistConfirm,
            titleVisibility: .visible
        ) {
            Button("Download all \(pendingPlaylistCount) items") {
                manager.enqueue(pendingPlaylistURL)
            }
            Button("Download first item only") {
                manager.enqueue(pendingPlaylistURL + " --no-playlist")
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    if urlText.isEmpty {
                        Text("Paste a URL to download…")
                            .foregroundStyle(palette.text(0.45))
                            .font(.body)
                            .padding(.leading, 10)
                            .padding(.vertical, 8)
                    }
                    TextField("", text: $urlText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...3)
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                        .tint(palette.accent)
                        .padding(.leading, 10)
                        .padding(.vertical, 8)
                        .accessibilityLabel("Video URL")
                        .onSubmit { startGet() }
                }

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(palette.text(0.7))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open settings")
            }
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(palette.border)
            )

            HStack(spacing: 10) {
                Button("Show in Finder") {
                    NSWorkspace.shared.open(AppSettings.shared.resolvedOutputFolder)
                }
                .accessibilityLabel("Open download folder in Finder")

                Spacer()

                Picker("Quality", selection: $settings.formatPreset) {
                    ForEach(FormatPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 160)
                .accessibilityLabel("Video quality preset")

                Spacer()

                Button("Cancel") {
                    manager.cancelAll()
                    urlText = ""
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(!manager.hasActive && urlText.isEmpty)
                .accessibilityLabel("Cancel all downloads and clear URL")

                Button("Get") {
                    startGet()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCheckingPlaylist)
                .buttonStyle(PaletteProminentButtonStyle(fill: palette.accent, label: palette.accentText))
                .accessibilityLabel("Start download")

                if isCheckingPlaylist {
                    ProgressView()
                        .scaleEffect(0.7)
                        .accessibilityLabel("Checking URL…")
                }
            }
        }
    }

    // MARK: - Queue Area

    private var queueArea: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Downloads")
                    .font(.caption)
                    .foregroundStyle(palette.text(0.6))
                    .padding(.leading, 16)
                Spacer()
                Button("Clear finished") {
                    manager.clearCompleted()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(palette.text(0.6))
                .disabled(!manager.queue.contains(where: { $0.status.isTerminal }))
                .padding(.trailing, 16)
                .accessibilityLabel("Remove completed and failed items from the list")
            }
            .padding(.vertical, 6)
            .background(palette.background)

            if manager.queue.isEmpty {
                Text("No downloads yet")
                    .font(.caption)
                    .foregroundStyle(palette.text(0.25))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.background)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(manager.queue) { item in
                                QueueRowView(
                                    item: item,
                                    onCancel: { manager.cancel(item: item) },
                                    onRemove: { manager.remove(item: item) }
                                )
                                .padding(.horizontal, 16)
                                Divider().padding(.horizontal, 16)
                            }
                            Color.clear.frame(height: 1).id("queueBottom")
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }

    // MARK: - Actions

    private func startGet() {
        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        urlText = ""

        Task {
            isCheckingPlaylist = true
            let count = await manager.checkPlaylist(url: url)
            isCheckingPlaylist = false

            if let count {
                pendingPlaylistURL = url
                pendingPlaylistCount = count
                showPlaylistConfirm = true
            } else {
                manager.enqueue(url)
            }
        }
    }

}
