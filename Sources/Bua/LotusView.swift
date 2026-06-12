import SwiftUI

/// A single petal: ovate, widest just above the middle, pointed tip.
/// `bow` (-1…1) bends the tip sideways so open petals curve away from
/// the flower's heart, the way lotus petals recurve as they bloom.
struct PetalShape: Shape {
    var bow: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let base = CGPoint(x: rect.midX, y: rect.maxY)
        let tip = CGPoint(x: rect.midX + bow * w * 0.55, y: rect.minY)
        var p = Path()
        p.move(to: base)
        p.addCurve(
            to: tip,
            control1: CGPoint(x: rect.midX - w * 0.60, y: rect.maxY - h * 0.18),
            control2: CGPoint(x: tip.x - w * 0.52, y: rect.minY + h * 0.45)
        )
        p.addCurve(
            to: base,
            control1: CGPoint(x: tip.x + w * 0.52, y: rect.minY + h * 0.45),
            control2: CGPoint(x: rect.midX + w * 0.60, y: rect.maxY - h * 0.18)
        )
        p.closeSubpath()
        return p
    }
}

/// The lotus. `t` is session utilization 0…1: at 0 the flower is a full
/// open bloom in sage; as t rises the petals fold inward (outer layer
/// first) and the color travels the day toward twilight. Animatable, so
/// changes in t glide rather than jump.
///
/// `breathPhase` is monotonic radians from the panel's timeline; the
/// whole flower swells ~3.5%, the petal fans open and close a whisper,
/// and inner layers lag the outer ones so the motion feels alive rather
/// than mechanical. 0 means still (reduce-motion, snapshots).
struct LotusView: View, @preconcurrency Animatable {
    var t: Double
    var resting: Bool
    var breathPhase: Double

    var animatableData: Double {
        get { t }
        set { t = newValue }
    }

    private struct PetalLayer {
        let count: Int
        let length: CGFloat
        let width: CGFloat
        let spread: Double     // half-fan angle in degrees at full bloom
        let lagStart: Double   // this layer only starts closing past this t
        let lighten: Double
    }

    // Odd counts give the classic Buddhist-iconography silhouette: one
    // upright center petal, symmetric pairs falling away beside it.
    private static let layers: [PetalLayer] = [
        PetalLayer(count: 7, length: 78, width: 26, spread: 85, lagStart: 0.00, lighten: 0.000),
        PetalLayer(count: 5, length: 64, width: 26, spread: 55, lagStart: 0.15, lighten: 0.055),
        PetalLayer(count: 3, length: 50, width: 24, spread: 25, lagStart: 0.30, lighten: 0.130),
    ]

    private static let canvasSize = CGSize(width: 180, height: 150)
    private static let basePoint = CGPoint(x: 90, y: 140)

    var body: some View {
        let journey = resting ? ColorJourney.resting : ColorJourney.at(t)
        let closure = resting ? 0.45 : t
        let breath = sin(breathPhase)

        ZStack {
            // Soft glow breathing behind the flower
            Circle()
                .fill(
                    RadialGradient(
                        colors: [journey.color.opacity(0.26 + 0.13 * breath), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 82 + 5 * breath
                    )
                )
                .frame(width: 175, height: 175)
                .position(x: Self.basePoint.x, y: Self.basePoint.y - 55)

            ForEach(Array(Self.layers.enumerated()), id: \.offset) { index, layer in
                petalLayer(index: index, layer: layer, journey: journey, closure: closure)
                    .zIndex(Double(index))
            }
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .scaleEffect(1 + 0.035 * breath, anchor: .bottom)
    }

    private func petalLayer(index: Int, layer: PetalLayer, journey: OKLCH, closure: Double) -> some View {
        // Layer-local closing with stagger: outer folds first
        let c = min(max((closure - layer.lagStart) / (1 - layer.lagStart), 0), 1)
        // Inner layers breathe a beat behind the outer ones
        let osc = breathPhase == 0 ? 0 : sin(breathPhase - Double(index) * 0.65)
        let spread = (layer.spread * (1 - c) + 6 * c) * (1 + 0.035 * osc)
        let petalWidth = layer.width * (1 - 0.38 * c) * (1 + 0.02 * osc)
        let petalLength = layer.length * (1 - 0.12 * c)
        let base = journey.lighter(layer.lighten)
        // Lotus petals run pale at the base and gather color toward the tip
        let bottom = base.lighter(0.14).softer(0.075)
        let top = OKLCH(l: max(0, base.l - 0.02), c: base.c + 0.01, h: base.h)
        let outline = OKLCH(l: max(0, base.l - 0.10), c: base.c, h: base.h).color.opacity(0.35)

        return ForEach(0..<layer.count, id: \.self) { i in
            let f = layer.count == 1 ? 0.5 : Double(i) / Double(layer.count - 1)
            let angle = -spread + 2 * spread * f
            // Tips curl back toward vertical so the bloom reads as a cup —
            // the bend opposes the petal's lean, strongest on outer petals
            let bow = CGFloat(-sin(angle * .pi / 180) * 0.45 * (1 - c))
            PetalShape(bow: bow)
                .fill(
                    LinearGradient(
                        colors: [bottom.color, top.color],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .overlay(
                    PetalShape(bow: bow)
                        .stroke(outline, lineWidth: 0.5)
                )
                .frame(width: petalWidth, height: petalLength)
                .rotationEffect(.degrees(angle), anchor: .bottom)
                .position(x: Self.basePoint.x, y: Self.basePoint.y - petalLength / 2)
        }
    }
}
