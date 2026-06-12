import SwiftUI

/// One color in OKLCH space. `h` is in degrees and may be "unwrapped"
/// (outside 0–360) so interpolation follows an intended hue direction.
struct OKLCH {
    var l: Double
    var c: Double
    var h: Double

    func lighter(_ dl: Double) -> OKLCH { OKLCH(l: min(1, l + dl), c: c, h: h) }
    func softer(_ dc: Double) -> OKLCH { OKLCH(l: l, c: max(0, c - dc), h: h) }

    var color: Color {
        let (r, g, b) = ColorJourney.srgb(from: self)
        return Color(.sRGB, red: r, green: g, blue: b)
    }

    var nsColor: NSColor {
        let (r, g, b) = ColorJourney.srgb(from: self)
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

enum ColorJourney {

    /// The day of the lotus: sage dawn → jade → lotus pink → sunset coral → twilight purple.
    /// Hues are unwrapped so each segment travels the intended way around the wheel:
    /// pink → coral rises through red like a sunset (350 → 415 ≡ 55), coral → purple
    /// falls back through magenta like dusk (415 → 300).
    private static let stops: [(t: Double, color: OKLCH)] = [
        (0.00, OKLCH(l: 0.62, c: 0.20, h: 145)),   // Benevolent sage (brand accent, exact)
        (0.30, OKLCH(l: 0.60, c: 0.14, h: 175)),   // jade
        (0.55, OKLCH(l: 0.70, c: 0.16, h: 350)),   // lotus pink
        (0.78, OKLCH(l: 0.66, c: 0.15, h: 415)),   // sunset coral (≡ hue 55)
        (1.00, OKLCH(l: 0.45, c: 0.10, h: 300)),   // twilight purple
    ]

    /// Resting lotus: sage with the color mostly let go of.
    static let resting = OKLCH(l: 0.58, c: 0.045, h: 145)

    static func at(_ t: Double) -> OKLCH {
        let t = min(max(t, 0), 1)
        for i in 0..<(stops.count - 1) {
            let (t0, c0) = stops[i]
            let (t1, c1) = stops[i + 1]
            if t <= t1 {
                let f = t1 == t0 ? 0 : (t - t0) / (t1 - t0)
                return OKLCH(
                    l: c0.l + (c1.l - c0.l) * f,
                    c: c0.c + (c1.c - c0.c) * f,
                    h: c0.h + (c1.h - c0.h) * f
                )
            }
        }
        return stops[stops.count - 1].color
    }

    // MARK: - OKLCH → sRGB (Björn Ottosson's OKLab definition)

    static func srgb(from oklch: OKLCH) -> (r: Double, g: Double, b: Double) {
        let hRad = oklch.h * .pi / 180
        let a = oklch.c * cos(hRad)
        let b = oklch.c * sin(hRad)
        let L = oklch.l

        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b

        let l3 = l_ * l_ * l_
        let m3 = m_ * m_ * m_
        let s3 = s_ * s_ * s_

        let rLin = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
        let gLin = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
        let bLin = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3

        return (encode(rLin), encode(gLin), encode(bLin))
    }

    private static func encode(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }
}
