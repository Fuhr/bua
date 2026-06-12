import SwiftUI

/// A single petal: teardrop made of two mirrored cubic Béziers,
/// base at bottom-center, soft tip at top-center.
struct PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let base = CGPoint(x: rect.midX, y: rect.maxY)
        let tip = CGPoint(x: rect.midX, y: rect.minY)
        p.move(to: base)
        p.addCurve(
            to: tip,
            control1: CGPoint(x: rect.midX - w * 0.62, y: rect.maxY - h * 0.28),
            control2: CGPoint(x: rect.midX - w * 0.52, y: rect.minY + h * 0.30)
        )
        p.addCurve(
            to: base,
            control1: CGPoint(x: rect.midX + w * 0.52, y: rect.minY + h * 0.30),
            control2: CGPoint(x: rect.midX + w * 0.62, y: rect.maxY - h * 0.28)
        )
        p.closeSubpath()
        return p
    }
}

/// The lotus. `t` is session utilization 0…1: at 0 the flower is a full
/// open bloom in sage; as t rises the petals fold inward (outer layer
/// first) and the color travels the day toward twilight. Animatable, so
/// changes in t glide rather than jump.
struct LotusView: View, @preconcurrency Animatable {
    var t: Double
    var resting: Bool
    var breath: Double   // -1…1 sine phase; drives scale + glow only

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

    private static let layers: [PetalLayer] = [
        PetalLayer(count: 8, length: 80, width: 34, spread: 78, lagStart: 0.00, lighten: 0.000),
        PetalLayer(count: 6, length: 63, width: 30, spread: 52, lagStart: 0.15, lighten: 0.045),
        PetalLayer(count: 4, length: 47, width: 26, spread: 26, lagStart: 0.30, lighten: 0.090),
    ]

    private static let canvasSize = CGSize(width: 180, height: 150)
    private static let basePoint = CGPoint(x: 90, y: 140)

    var body: some View {
        let journey = resting ? ColorJourney.resting : ColorJourney.at(t)
        let closure = resting ? 0.45 : t

        ZStack {
            // Soft glow breathing behind the flower
            Circle()
                .fill(
                    RadialGradient(
                        colors: [journey.color.opacity(0.28 + 0.10 * breath), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 85
                    )
                )
                .frame(width: 170, height: 170)
                .position(x: Self.basePoint.x, y: Self.basePoint.y - 55)

            ForEach(Array(Self.layers.enumerated()), id: \.offset) { index, layer in
                petalLayer(layer, journey: journey, closure: closure)
                    .zIndex(Double(index))
            }

            // Seed at the heart, visible inside the open bloom
            Circle()
                .fill(journey.lighter(0.18).softer(0.06).color)
                .frame(width: 13, height: 13)
                .position(x: Self.basePoint.x, y: Self.basePoint.y - 12)
                .zIndex(1.5)
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .scaleEffect(1 + 0.02 * breath, anchor: .bottom)
    }

    private func petalLayer(_ layer: PetalLayer, journey: OKLCH, closure: Double) -> some View {
        // Layer-local closing with stagger: outer folds first
        let c = min(max((closure - layer.lagStart) / (1 - layer.lagStart), 0), 1)
        let spread = layer.spread * (1 - c) + 5 * c
        let petalWidth = layer.width * (1 - 0.45 * c)
        let petalLength = layer.length * (1 - 0.15 * c)
        let base = journey.lighter(layer.lighten)
        let bottom = OKLCH(l: max(0, base.l - 0.06), c: base.c, h: base.h)
        let top = base.lighter(0.05)

        return ForEach(0..<layer.count, id: \.self) { i in
            let f = layer.count == 1 ? 0.5 : Double(i) / Double(layer.count - 1)
            let angle = -spread + 2 * spread * f
            PetalShape()
                .fill(
                    LinearGradient(
                        colors: [bottom.color, top.color],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .overlay(
                    PetalShape()
                        .stroke(OKLCH(l: max(0, base.l - 0.10), c: base.c, h: base.h).color.opacity(0.30), lineWidth: 0.5)
                )
                .frame(width: petalWidth, height: petalLength)
                .rotationEffect(.degrees(angle), anchor: .bottom)
                .position(x: Self.basePoint.x, y: Self.basePoint.y - petalLength / 2)
        }
    }
}
