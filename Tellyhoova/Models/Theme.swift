import SwiftUI

// MARK: - Color hex helper

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Palette

struct Palette {
    let background: Color      // window background
    let surface: Color         // input field / raised areas
    let border: Color          // hairline borders (already includes alpha)
    let accent: Color          // Get button + progress bar
    let accentText: Color      // label/glyph sitting on the accent fill
    let textPrimary: Color     // base text colour (use text(_:) for muted variants)
    let success: Color         // completed
    let error: Color           // failed
    let progress: Color        // download progress bar
    let logBackground: Color   // terminal log panel background
    let logText: Color         // terminal log panel text

    func text(_ opacity: Double) -> Color { textPrimary.opacity(opacity) }
}

// MARK: - Themes

enum AppTheme: String, CaseIterable, Identifiable {
    case studioSlate = "Studio Slate"
    case signalAmber = "Signal Amber"
    case aurora      = "Aurora"

    var id: String { rawValue }

    var palette: Palette {
        switch self {
        case .studioSlate:
            return Palette(
                background:    Color(hex: 0x1B1E24),
                surface:       Color(hex: 0x23272F),
                border:        Color.white.opacity(0.14),
                accent:        Color(hex: 0x4C8BF5),
                accentText:    Color.white,
                textPrimary:   Color(hex: 0xE6E8EC),
                success:       Color(hex: 0x46C46A),
                error:         Color(hex: 0xF0625D),
                progress:      Color(hex: 0x4C8BF5),
                logBackground: Color(hex: 0x101319),
                logText:       Color(hex: 0x8AD88A)
            )
        case .signalAmber:
            return Palette(
                background:    Color(hex: 0x1A1714),
                surface:       Color(hex: 0x241F1A),
                border:        Color(hex: 0xFFF0DC, alpha: 0.14),
                accent:        Color(hex: 0xF0A429),
                accentText:    Color(hex: 0x1A1714),
                textPrimary:   Color(hex: 0xF3ECE1),
                success:       Color(hex: 0x6FBF4F),
                error:         Color(hex: 0xE5564F),
                progress:      Color(hex: 0xF0A429),
                logBackground: Color(hex: 0x0F0C08),
                logText:       Color(hex: 0xF0B34A)
            )
        case .aurora:
            return Palette(
                background:    Color(hex: 0x14172A),
                surface:       Color(hex: 0x1D2240),
                border:        Color(hex: 0xC8D2FF, alpha: 0.14),
                accent:        Color(hex: 0x2DD4BF),
                accentText:    Color(hex: 0x0C1F1B),
                textPrimary:   Color(hex: 0xE7EAF5),
                success:       Color(hex: 0x34D399),
                error:         Color(hex: 0xFB7185),
                progress:      Color(hex: 0x2DD4BF),
                logBackground: Color(hex: 0x0D0F1F),
                logText:       Color(hex: 0x5EEAD4)
            )
        }
    }
}

// MARK: - Prominent button styled from the active palette

struct PaletteProminentButtonStyle: ButtonStyle {
    let fill: Color
    let label: Color

    func makeBody(configuration: Configuration) -> some View {
        Inner(configuration: configuration, fill: fill, label: label)
    }

    struct Inner: View {
        let configuration: ButtonStyleConfiguration
        let fill: Color
        let label: Color
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.body.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(fill.opacity(configuration.isPressed ? 0.75 : 1.0))
                .foregroundStyle(label)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .opacity(isEnabled ? 1.0 : 0.4)
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
