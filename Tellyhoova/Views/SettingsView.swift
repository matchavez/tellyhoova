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
            DependenciesTab()
                .tabItem { Label("Dependencies", systemImage: "checkmark.shield") }
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

                if settings.formatPreset.audioFormat != nil {
                    Picker("Audio bitrate", selection: $settings.audioBitrate) {
                        ForEach(AudioBitrate.allCases) { bitrate in
                            Text(bitrate.rawValue).tag(bitrate)
                        }
                    }
                    .accessibilityLabel("Audio bitrate")
                }
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
        case .audioOnly:
            Text("Extracts audio only, keeping the source codec as-is — usually Opus (.opus) for YouTube.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .audioM4A:
            Text("Extracts audio only and transcodes to AAC (.m4a) at the bitrate below — plays natively in QuickTime Player and iOS.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .audioMP3:
            Text("Extracts audio only and transcodes to MP3 (.mp3) at the bitrate below.")
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

// MARK: - Dependencies

private struct DependenciesTab: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var deps = DependencyManager.shared

    var body: some View {
        Form {
            Section {
                DependencyRow(
                    title: "yt-dlp",
                    state: deps.ytdlp,
                    installTitle: "Install with Homebrew",
                    isInstalling: deps.isInstalling
                ) { Task { await deps.install(.ytdlp) } }

                LabeledContent("Path") {
                    TextField("/opt/homebrew/bin/yt-dlp", text: $settings.ytdlpPath)
                        .font(.system(.caption, design: .monospaced))
                        .accessibilityLabel("Path to yt-dlp executable")
                }
            } header: {
                Text("yt-dlp")
            } footer: {
                Text("Downloads the video/audio. Required for everything in Tellyhoova.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                DependencyRow(
                    title: "ffmpeg",
                    state: deps.ffmpeg,
                    installTitle: "Install with Homebrew",
                    isInstalling: deps.isInstalling
                ) { Task { await deps.install(.ffmpeg) } }
            } header: {
                Text("ffmpeg")
            } footer: {
                Text("Merges video/audio streams, transcodes audio formats, and handles metadata/thumbnail embedding.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                DependencyRow(
                    title: "Pillow",
                    state: deps.pillow,
                    installTitle: "Install into yt-dlp's Python",
                    isInstalling: deps.isInstalling
                ) { Task { await deps.install(.pillow) } }
            } header: {
                Text("Thumbnail Embedding")
            } footer: {
                Text("YouTube thumbnails are WebP images, and MP4/M4A files can't store WebP as cover art directly — yt-dlp needs Pillow to convert them first. Without it, downloads with \"Embed thumbnail\" on will finish extracting audio/video but still report Failed at the embed step.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                DependencyRow(
                    title: "Homebrew",
                    state: deps.homebrew,
                    installTitle: "Show install command",
                    isInstalling: deps.isInstalling
                ) { Task { await deps.install(.homebrew) } }
            } header: {
                Text("Homebrew")
            } footer: {
                Text("Package manager used to install yt-dlp and ffmpeg. Installing it requires an interactive Terminal session, so Tellyhoova can only hand you the command.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !deps.installLog.isEmpty {
                Section {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(Array(deps.installLog.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(size: 10, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                Color.clear.frame(height: 1).id("depLogEnd")
                            }
                            .padding(6)
                        }
                        .frame(maxHeight: 160)
                        .background(Color.black.opacity(0.85))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .accessibilityLabel("Dependency install log")
                        .onChange(of: deps.installLog.count) { _, _ in
                            proxy.scrollTo("depLogEnd", anchor: .bottom)
                        }
                    }
                } header: {
                    Text("Install Output")
                }
            }

            Section {
                Button {
                    Task { await deps.checkAll() }
                } label: {
                    HStack(spacing: 6) {
                        if deps.isChecking {
                            ProgressView().scaleEffect(0.6)
                        }
                        Text("Check Again")
                    }
                }
                .disabled(deps.isInstalling || deps.isChecking)
                .accessibilityLabel("Re-check dependencies")
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            await deps.checkAll()
        }
    }
}

private struct DependencyRow: View {
    let title: String
    let state: DependencyState
    let installTitle: String
    let isInstalling: Bool
    let onInstall: () -> Void

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                statusText
                if case .missing = state {
                    Button(installTitle, action: onInstall)
                        .disabled(isInstalling)
                }
            }
        } label: {
            HStack(spacing: 6) {
                statusDot
                Text(title)
            }
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        switch state {
        case .checking:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 8, height: 8)
                .accessibilityLabel("\(title): checking")
        case .ok:
            Circle().fill(Color.green).frame(width: 8, height: 8)
                .accessibilityLabel("\(title): found")
        case .missing:
            Circle().fill(Color.red).frame(width: 8, height: 8)
                .accessibilityLabel("\(title): missing")
        case .notApplicable:
            Circle().fill(Color.gray).frame(width: 8, height: 8)
                .accessibilityLabel("\(title): not applicable")
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch state {
        case .checking:
            Text("Checking…").font(.caption).foregroundStyle(.secondary)
        case .ok(let detail):
            Text(detail ?? "Found").font(.caption).foregroundStyle(.secondary)
        case .missing:
            Text("Not found").font(.caption).foregroundStyle(.red)
        case .notApplicable(let reason):
            Text(reason).font(.caption).foregroundStyle(.secondary)
        }
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
