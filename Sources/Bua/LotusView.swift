import SwiftUI

/// One lotus petal, drawn the way the classic lotus icons draw them
/// (studied from Søren's Noun Project references): two cubic Béziers
/// from a shared base point to a pointed tip. The petal leaves the base
/// leaning steeply outward (`baseTangent`), then the spine curves so the
/// tip points nearly upward — an almond shape, pointed at both ends,
/// that "flowers from the base".
struct LotusPetalShape: Shape {
    var base: CGPoint
    var tipAngle: Double      // tip position, degrees from vertical (+ = right)
    var baseTangent: Double   // direction the petal leaves the base, degrees
    var length: CGFloat
    var halfWidth: CGFloat    // maximum half-width of the petal

    func path(in rect: CGRect) -> Path {
        func polar(_ degrees: Double, _ r: CGFloat) -> CGVector {
            let rad = degrees * .pi / 180
            return CGVector(dx: sin(rad) * r, dy: -cos(rad) * r)
        }
        let tipV = polar(tipAngle, length)
        let tip = CGPoint(x: base.x + tipV.dx, y: base.y + tipV.dy)
        // Spine: quadratic from base toward the base tangent, into the tip —
        // the petal leaves steep and outward, then curls up
        let ctrlV = polar(baseTangent, length * 0.55)
        let ctrl = CGPoint(x: base.x + ctrlV.dx, y: base.y + ctrlV.dy)

        func spine(_ s: CGFloat) -> CGPoint {
            let u = 1 - s
            return CGPoint(
                x: u * u * base.x + 2 * u * s * ctrl.x + s * s * tip.x,
                y: u * u * base.y + 2 * u * s * ctrl.y + s * s * tip.y
            )
        }
        func normal(_ s: CGFloat) -> CGVector {
            let u = 1 - s
            let dx = 2 * u * (ctrl.x - base.x) + 2 * s * (tip.x - ctrl.x)
            let dy = 2 * u * (ctrl.y - base.y) + 2 * s * (tip.y - ctrl.y)
            let len = max(sqrt(dx * dx + dy * dy), 0.001)
            return CGVector(dx: -dy / len, dy: dx / len)
        }
        // Pointed ellipse: zero at both ends, widest just past the middle
        func width(_ s: CGFloat) -> CGFloat {
            halfWidth * pow(sin(.pi * pow(s, 0.85)), 0.9)
        }

        let steps = 26
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for i in 0...steps {
            let s = CGFloat(i) / CGFloat(steps)
            let p = spine(s)
            let n = normal(s)
            let w = width(s)
            left.append(CGPoint(x: p.x + n.dx * w, y: p.y + n.dy * w))
            right.append(CGPoint(x: p.x - n.dx * w, y: p.y - n.dy * w))
        }
        var path = Path()
        path.move(to: left[0])
        for p in left.dropFirst() { path.addLine(to: p) }
        for p in right.reversed() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }
}

/// The lotus. `t` is session utilization 0…1: at 0 the flower is a full
/// open bloom in sage; as t rises the petals gather toward vertical into
/// a bud while the color travels the day toward twilight. Animatable.
///
/// `breathPhase` is monotonic radians; the fan opens/closes a whisper,
/// the flower swells ~3%, and the inner ring lags the outer one.
/// 0 means still (reduce-motion, snapshots).
struct LotusView: View, @preconcurrency Animatable {
    var t: Double
    var resting: Bool
    var breathPhase: Double

    var animatableData: Double {
        get { t }
        set { t = newValue }
    }

    private struct PetalSpec {
        let angle: Double     // tip angle at full bloom
        let length: CGFloat
        let ring: Int         // 0 = outer (back), 1 = inner (front, lighter)
    }

    /// Few, fat, overlapping petals (the icon references run width/length
    /// ≈ 0.45). Tip envelope is a dome: center tallest, outer wings low.
    private static let petals: [PetalSpec] = [
        PetalSpec(angle: -68, length: 54, ring: 0),
        PetalSpec(angle: 68, length: 54, ring: 0),
        PetalSpec(angle: -34, length: 68, ring: 0),
        PetalSpec(angle: 34, length: 68, ring: 0),
        PetalSpec(angle: 0, length: 80, ring: 0),
        PetalSpec(angle: -22, length: 44, ring: 1),
        PetalSpec(angle: 22, length: 44, ring: 1),
        PetalSpec(angle: 0, length: 52, ring: 1),
    ]

    private static let canvasSize = CGSize(width: 180, height: 150)
    private static let basePoint = CGPoint(x: 90, y: 142)

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

            // Back ring first; within a ring, outer petals first so the
            // center petal sits on top — the classic icon layering.
            ForEach(Array(Self.petals.enumerated()), id: \.offset) { _, spec in
                petal(spec, journey: journey, closure: closure)
                    .zIndex(Double(spec.ring) * 100 + (90 - abs(spec.angle)))
            }
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        .scaleEffect(1 + 0.03 * breath, anchor: .bottom)
    }

    @ViewBuilder
    private func petal(_ spec: PetalSpec, journey: OKLCH, closure: Double) -> some View {
        // Inner ring closes later than the outer one
        let c = spec.ring == 0
            ? closure
            : min(max((closure - 0.25) / 0.75, 0), 1)
        // Inner ring breathes a beat behind
        let osc = breathPhase == 0 ? 0 : sin(breathPhase - Double(spec.ring) * 0.65)

        // Closing gathers tips toward vertical and straightens the spine
        let angle = spec.angle * (1 - 0.93 * c) * (1 + 0.045 * osc)
        // Wings may leave the base just below horizontal (>90°), dipping
        // low before curling up — that's what opens the bowl silhouette
        let baseTangent = min(max(angle * 1.5, -94), 94)
        let length = spec.length * (1 - 0.13 * c)
        let halfWidth = length * 0.23 * (1 - 0.25 * c)

        // Outer petals run a touch deeper so overlapping petals read
        // individually instead of fusing into one mass
        let depth = spec.ring == 0 ? 0.055 * abs(spec.angle) / 62 : 0
        let ringColor = spec.ring == 0
            ? OKLCH(l: max(0, journey.l - depth), c: journey.c, h: journey.h)
            : journey.lighter(0.10).softer(0.02)
        // Petals run pale at the base and gather color toward the tip
        let pale = ringColor.lighter(0.13).softer(0.07)
        let deep = OKLCH(l: max(0, ringColor.l - 0.02), c: ringColor.c + 0.01, h: ringColor.h)
        let outline = OKLCH(l: max(0, ringColor.l - 0.10), c: ringColor.c, h: ringColor.h)
            .color.opacity(0.35)

        let shape = LotusPetalShape(
            base: Self.basePoint,
            tipAngle: angle,
            baseTangent: baseTangent,
            length: length,
            halfWidth: halfWidth
        )
        let tipRad = angle * .pi / 180
        let tipUnit = UnitPoint(
            x: (Self.basePoint.x + sin(tipRad) * length) / Self.canvasSize.width,
            y: (Self.basePoint.y - cos(tipRad) * length) / Self.canvasSize.height
        )
        let baseUnit = UnitPoint(
            x: Self.basePoint.x / Self.canvasSize.width,
            y: Self.basePoint.y / Self.canvasSize.height
        )

        shape
            .fill(
                LinearGradient(
                    colors: [pale.color, deep.color],
                    startPoint: baseUnit,
                    endPoint: tipUnit
                )
            )
            .overlay(shape.stroke(outline, lineWidth: 1.0))
    }
}
