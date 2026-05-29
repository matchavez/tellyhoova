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
    case studioSlate      = "Studio Slate"
    case signalAmber      = "Signal Amber"
    case aurora           = "Aurora"
    case midnightOcean    = "Midnight Ocean"
    case forestDark       = "Forest Dark"
    case roseNoir         = "Rose Noir"
    case crimsonDark      = "Crimson Dark"
    case deepPurple       = "Deep Purple"
    case cyberpunk        = "Cyberpunk"
    case vintageTerminal  = "Vintage Terminal"
    case sunset           = "Sunset"
    case steelBlue        = "Steel Blue"
    case arctic           = "Arctic"
    case parchment        = "Parchment"

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
        case .midnightOcean:
            return Palette(
                background:    Color(hex: 0x0D1B2A),
                surface:       Color(hex: 0x162032),
                border:        Color(hex: 0x64C8FF, alpha: 0.14),
                accent:        Color(hex: 0x00B4D8),
                accentText:    Color(hex: 0x0D1B2A),
                textPrimary:   Color(hex: 0xCAF0F8),
                success:       Color(hex: 0x48CAE4),
                error:         Color(hex: 0xEF476F),
                progress:      Color(hex: 0x00B4D8),
                logBackground: Color(hex: 0x060E17),
                logText:       Color(hex: 0x48CAE4)
            )
        case .forestDark:
            return Palette(
                background:    Color(hex: 0x0F1F14),
                surface:       Color(hex: 0x162A1C),
                border:        Color(hex: 0x64C864, alpha: 0.14),
                accent:        Color(hex: 0x52B788),
                accentText:    Color(hex: 0x0F1F14),
                textPrimary:   Color(hex: 0xD8F3DC),
                success:       Color(hex: 0x52B788),
                error:         Color(hex: 0xE5383B),
                progress:      Color(hex: 0x52B788),
                logBackground: Color(hex: 0x080F0A),
                logText:       Color(hex: 0x74C69D)
            )
        case .roseNoir:
            return Palette(
                background:    Color(hex: 0x1A1118),
                surface:       Color(hex: 0x251A23),
                border:        Color(hex: 0xFFB6C1, alpha: 0.14),
                accent:        Color(hex: 0xFF6B9D),
                accentText:    Color(hex: 0x1A1118),
                textPrimary:   Color(hex: 0xF5E6F0),
                success:       Color(hex: 0xA8E6CF),
                error:         Color(hex: 0xFF6B6B),
                progress:      Color(hex: 0xFF6B9D),
                logBackground: Color(hex: 0x0F0A0D),
                logText:       Color(hex: 0xFF8FB1)
            )
        case .crimsonDark:
            return Palette(
                background:    Color(hex: 0x1A0A0A),
                surface:       Color(hex: 0x2A1010),
                border:        Color(hex: 0xFF6464, alpha: 0.14),
                accent:        Color(hex: 0xE63946),
                accentText:    Color(hex: 0xFFF0F0),
                textPrimary:   Color(hex: 0xF8DCDC),
                success:       Color(hex: 0x57CC99),
                error:         Color(hex: 0xFF6B6B),
                progress:      Color(hex: 0xE63946),
                logBackground: Color(hex: 0x0F0505),
                logText:       Color(hex: 0xFF9A9A)
            )
        case .deepPurple:
            return Palette(
                background:    Color(hex: 0x1A0E2E),
                surface:       Color(hex: 0x251540),
                border:        Color(hex: 0xC896FF, alpha: 0.14),
                accent:        Color(hex: 0x9D4EDD),
                accentText:    Color(hex: 0xF0E8FF),
                textPrimary:   Color(hex: 0xE8D5FF),
                success:       Color(hex: 0x57CC99),
                error:         Color(hex: 0xFF4D6D),
                progress:      Color(hex: 0x9D4EDD),
                logBackground: Color(hex: 0x0D0619),
                logText:       Color(hex: 0xC77DFF)
            )
        case .cyberpunk:
            return Palette(
                background:    Color(hex: 0x0A0A12),
                surface:       Color(hex: 0x12121E),
                border:        Color(hex: 0xFFE600, alpha: 0.18),
                accent:        Color(hex: 0xFFE600),
                accentText:    Color(hex: 0x0A0A12),
                textPrimary:   Color(hex: 0xE8E8F0),
                success:       Color(hex: 0x00FF9F),
                error:         Color(hex: 0xFF2D55),
                progress:      Color(hex: 0xFFE600),
                logBackground: Color(hex: 0x050508),
                logText:       Color(hex: 0x00FF9F)
            )
        case .vintageTerminal:
            return Palette(
                background:    Color(hex: 0x0A0F0A),
                surface:       Color(hex: 0x0F160F),
                border:        Color(hex: 0x32C832, alpha: 0.20),
                accent:        Color(hex: 0x33FF33),
                accentText:    Color(hex: 0x0A0F0A),
                textPrimary:   Color(hex: 0xAAFFAA),
                success:       Color(hex: 0x33FF33),
                error:         Color(hex: 0xFF3333),
                progress:      Color(hex: 0x33FF33),
                logBackground: Color(hex: 0x050A05),
                logText:       Color(hex: 0x22CC22)
            )
        case .sunset:
            return Palette(
                background:    Color(hex: 0x1A1020),
                surface:       Color(hex: 0x251830),
                border:        Color(hex: 0xFF9664, alpha: 0.14),
                accent:        Color(hex: 0xFF6B35),
                accentText:    Color(hex: 0x1A1020),
                textPrimary:   Color(hex: 0xFFE5D9),
                success:       Color(hex: 0x95D5B2),
                error:         Color(hex: 0xFF4D6D),
                progress:      Color(hex: 0xFF6B35),
                logBackground: Color(hex: 0x0F0812),
                logText:       Color(hex: 0xFFB347)
            )
        case .steelBlue:
            return Palette(
                background:    Color(hex: 0x1C2331),
                surface:       Color(hex: 0x243040),
                border:        Color(hex: 0x96C8FF, alpha: 0.14),
                accent:        Color(hex: 0x5B9BD5),
                accentText:    Color.white,
                textPrimary:   Color(hex: 0xD0DCF0),
                success:       Color(hex: 0x4CAF72),
                error:         Color(hex: 0xF05050),
                progress:      Color(hex: 0x5B9BD5),
                logBackground: Color(hex: 0x111820),
                logText:       Color(hex: 0x7EB8E8)
            )
        case .arctic:
            return Palette(
                background:    Color(hex: 0xF0F4F8),
                surface:       Color(hex: 0xFFFFFF),
                border:        Color.black.opacity(0.12),
                accent:        Color(hex: 0x0077B6),
                accentText:    Color.white,
                textPrimary:   Color(hex: 0x1B2A3B),
                success:       Color(hex: 0x0A9E52),
                error:         Color(hex: 0xD62828),
                progress:      Color(hex: 0x0077B6),
                logBackground: Color(hex: 0xE2EBF3),
                logText:       Color(hex: 0x1B5E85)
            )
        case .parchment:
            return Palette(
                background:    Color(hex: 0xF5F0E8),
                surface:       Color(hex: 0xFFF8ED),
                border:        Color.black.opacity(0.12),
                accent:        Color(hex: 0x8B4513),
                accentText:    Color(hex: 0xFFF8ED),
                textPrimary:   Color(hex: 0x2C1810),
                success:       Color(hex: 0x3D7A2E),
                error:         Color(hex: 0xB22222),
                progress:      Color(hex: 0x8B4513),
                logBackground: Color(hex: 0xE8DFD0),
                logText:       Color(hex: 0x5C3D1A)
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
