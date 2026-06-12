import SwiftUI

/// Benevolent design tokens, adapted for a tiny native panel.
/// Source of truth: benevolent-pm `globals.css` — warm cream / near-black surfaces
/// (hue ~85 warm neutrals), sage accent oklch(0.62 0.20 145).
enum Theme {
    static let sage = OKLCH(l: 0.62, c: 0.20, h: 145)

    struct Palette {
        let panelTint: Color
        let textPrimary: Color
        let textSecondary: Color
        let track: Color
        let border: Color
    }

    static func palette(for scheme: ColorScheme) -> Palette {
        switch scheme {
        case .dark:
            return Palette(
                panelTint: OKLCH(l: 0.10, c: 0.005, h: 85).color.opacity(0.55),
                textPrimary: OKLCH(l: 0.96, c: 0.012, h: 85).color,
                textSecondary: OKLCH(l: 0.65, c: 0.015, h: 80).color,
                track: Color.white.opacity(0.10),
                border: Color.white.opacity(0.10)
            )
        default:
            return Palette(
                panelTint: OKLCH(l: 0.985, c: 0.005, h: 85).color.opacity(0.55),
                textPrimary: OKLCH(l: 0.14, c: 0.005, h: 85).color,
                textSecondary: OKLCH(l: 0.50, c: 0.015, h: 85).color,
                track: Color.black.opacity(0.08),
                border: Color.black.opacity(0.08)
            )
        }
    }
}
