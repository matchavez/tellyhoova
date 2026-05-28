import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            FormatTab()
                .tabItem { Label("Format", systemImage: "film") }
            AppearanceTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            OutputTab()
                .tabItem { Label("Output", systemImage: "folder") }
            SubtitlesTab()
                .tabItem { Label("Subtitles", systemImage: "captions.bubble") }
            NetworkTab()
                .tabItem { Label("Network", systemImage: "network") }
            AdvancedTab()
                .tabItem { Label("Advanced", systemImage: "gearshape.2") }
        }
        .frame(width: 480)
        .padding()
        .overlay(alignment: .topLeading) {
            TrafficLightCloseButton { dismiss() }
                .padding(.top, 8)
                .padding(.leading, 8)
        }
    }
}

// MARK: - Format

private struct FormatTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Picker("Quality preset", selection: $settings.formatPreset) {
                    ForEach(FormatPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .accessibilityLabel("Video quality preset")

                if settings.formatPreset != .custom {
                    LabeledContent("Format string") {
                        Text(settings.formatPreset.formatString)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } else {
                    LabeledContent("Custom -f string") {
                        TextField("e.g. bv*+ba/b", text: $settings.customFormat)
                            .font(.system(.body, design: .monospaced))
                            .accessibilityLabel("Custom format string")
                    }
                }

                presetNote
            } header: {
                Text("Video Format")
            }

            Section {
                Toggle("Embed thumbnail", isOn: $settings.embedThumbnail)
                Toggle("Embed metadata", isOn: $settings.embedMetadata)
                Toggle("Remove SponsorBlock segments", isOn: $settings.sponsorblockRemove)
            } header: {
                Text("Post-processing")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var presetNote: some View {
        switch settings.formatPreset {
        case .quicktimeCompatible:
            Text("Downloads H.264 video (≤ 1080p) and AAC audio — plays natively in QuickTime Player. Videos shot above 1080p will be capped here; use Best Quality if you need full resolution and don't mind using VLC or IINA.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .bestQuality:
            Text("Downloads the highest available resolution and bitrate, which may be VP9 or AV1 at 4K or higher. These files will not open in QuickTime Player — use VLC or IINA to play them.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .best1080p, .best720p, .best480p:
            Text("Downloads the best available stream at or below the selected resolution. May use VP9 or AV1 codecs — these won't open in QuickTime Player. Use VLC or IINA to play them, or switch to QuickTime Compatible for native playback.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .audioOnly, .audioMP3:
            Text("Extracts audio only — no video track is downloaded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .custom:
            EmptyView()
        }
    }
}

// MARK: - Appearance

private struct AppearanceTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $settings.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.inline)
                .accessibilityLabel("Colour theme")
            } header: {
                Text("Colour Theme")
            } footer: {
                Text("Studio Slate is a neutral blue-accented look. Signal Amber is a warm broadcast palette. Aurora is a cool teal-on-indigo scheme. Changes apply instantly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Output

private struct OutputTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                LabeledContent("Download folder") {
                    HStack {
                        Text(settings.resolvedOutputFolder.path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.prompt = "Select Folder"
                            if panel.runModal() == .OK, let url = panel.url {
                                settings.setOutputFolder(url)
                            }
                        }
                        .accessibilityLabel("Choose download folder")
                    }
                }

                LabeledContent("Filename template") {
                    TextField("%(title)s.%(ext)s", text: $settings.outputTemplate)
                        .font(.system(.body, design: .monospaced))
                        .accessibilityLabel("Output filename template")
                }
            } header: {
                Text("File Location")
            }

            Section {
                Toggle("Send notification when download completes", isOn: $settings.notificationsEnabled)
            } header: {
                Text("Notifications")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Subtitles

private struct SubtitlesTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("Download subtitles", isOn: $settings.writeSubtitles)
                if settings.writeSubtitles {
                    LabeledContent("Languages") {
                        TextField("e.g. en,fr,es", text: $settings.subtitleLanguages)
                            .accessibilityLabel("Subtitle language codes, comma separated")
                    }
                }
                Toggle("Include auto-generated subtitles", isOn: $settings.autoSubtitles)
            } header: {
                Text("Subtitles")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Network

private struct NetworkTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                LabeledContent("Rate limit") {
                    TextField("e.g. 2M, 500K (blank = unlimited)", text: $settings.rateLimit)
                        .accessibilityLabel("Download rate limit")
                }
                Stepper("Retries: \(settings.retries)", value: $settings.retries, in: 0...50)
                    .accessibilityLabel("Number of retries: \(settings.retries)")
                Stepper("Concurrent fragments: \(settings.concurrentFragments)", value: $settings.concurrentFragments, in: 1...16)
                    .accessibilityLabel("Concurrent fragments: \(settings.concurrentFragments)")
            } header: {
                Text("Connection")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Advanced

private struct AdvancedTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                LabeledContent("yt-dlp path") {
                    HStack(spacing: 6) {
                        TextField("/opt/homebrew/bin/yt-dlp", text: $settings.ytdlpPath)
                            .font(.system(.body, design: .monospaced))
                            .accessibilityLabel("Path to yt-dlp executable")
                        Circle()
                            .fill(settings.ytdlpExists ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                            .accessibilityLabel(settings.ytdlpExists ? "yt-dlp found" : "yt-dlp not found")
                    }
                }
                if !settings.ytdlpExists {
                    Text("yt-dlp not found at this path. Install with: brew install yt-dlp")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("yt-dlp")
            } footer: {
                Text("Homebrew typically installs yt-dlp at /opt/homebrew/bin/yt-dlp (Apple Silicon) or /usr/local/bin/yt-dlp (Intel).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Traffic Light Close Button

private struct TrafficLightCloseButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.373, blue: 0.337))
                    .frame(width: 12, height: 12)
                if isHovering {
                    Image(systemName: "xmark")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundStyle(Color(red: 0.35, green: 0, blue: 0))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("Close settings")
    }
}
