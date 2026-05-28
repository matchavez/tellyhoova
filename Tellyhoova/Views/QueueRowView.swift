import SwiftUI

struct QueueRowView: View {
    @State var item: DownloadItem
    var onCancel: () -> Void
    var onRemove: () -> Void

    @ObservedObject private var settings = AppSettings.shared
    private var palette: Palette { settings.theme.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // URL row + action button
            HStack(spacing: 8) {
                statusIcon
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text(item.displayURL)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(palette.text(0.9))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityLabel("URL: \(item.url)")
                Spacer()
                if !item.status.isTerminal {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(palette.text(0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel download")
                } else {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(palette.text(0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove from list")
                }
            }

            // Progress bar + status — always visible above the log
            if case .downloading = item.status {
                ProgressView(value: item.progress)
                    .tint(palette.progress)
                    .accessibilityLabel("Download progress \(Int(item.progress * 100)) percent")
            }
            Text(item.statusText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(statusColor)
                .lineLimit(1)

            // Log toggle + self-contained scrolling panel
            if !item.log.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        item.isLogExpanded.toggle()
                    }
                } label: {
                    Label(item.isLogExpanded ? "Hide log" : "Show log",
                          systemImage: item.isLogExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(palette.text(0.55))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isLogExpanded ? "Collapse log" : "Expand log")

                if item.isLogExpanded {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical) {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(Array(item.log.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(palette.logText)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                Color.clear.frame(height: 1).id("logEnd-\(item.id)")
                            }
                            .padding(6)
                        }
                        .frame(maxHeight: 260)
                        .background(palette.logBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(palette.border))
                        .accessibilityLabel("Download log")
                        .onChange(of: item.log.count) { _, _ in
                            proxy.scrollTo("logEnd-\(item.id)", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(palette.text(0.5))
        case .checkingPlaylist:
            ProgressView().scaleEffect(0.6)
        case .downloading:
            ProgressView().scaleEffect(0.6)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(palette.success)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(palette.error)
        case .cancelled:
            Image(systemName: "slash.circle")
                .foregroundStyle(palette.text(0.4))
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .completed: return palette.success
        case .failed:    return palette.error
        case .cancelled: return palette.text(0.4)
        case .downloading: return palette.text(0.75)
        default:         return palette.text(0.6)
        }
    }
}
