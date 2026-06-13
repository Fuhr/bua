import AppKit

/// `Bua --icon [path.png]` — renders the app icon: the fully-bloomed lotus
/// (green outer petals cradling pink inner ones) on a soft light tile.
/// Outputs a 1024px master PNG; `make icon` slices it into AppIcon.icns.
///
/// Same petal construction as the panel lotus and the menu-bar glyph
/// (quadratic spine from a steep base tangent, pointed-ellipse width),
/// drawn at full bloom (closure 0) and filled instead of stroked.
@MainActor
enum Icon {
    private struct Petal {
        let angle: Double     // tip angle from vertical, + = right
        let length: Double
        let ring: Int         // 0 = outer (green), 1 = inner (pink)
    }

    private static let petals: [Petal] = [
        Petal(angle: -68, length: 54, ring: 0),
        Petal(angle:  68, length: 54, ring: 0),
        Petal(angle: -34, length: 68, ring: 0),
        Petal(angle:  34, length: 68, ring: 0),
        Petal(angle:   0, length: 80, ring: 0),
        Petal(angle: -22, length: 44, ring: 1),
        Petal(angle:  22, length: 44, ring: 1),
        Petal(angle:   0, length: 52, ring: 1),
    ]

    // Back ring first; within a ring, outer petals first so the center sits on top.
    private static func z(_ p: Petal) -> Double { Double(p.ring) * 100 + (90 - abs(p.angle)) }

    static func run(outputPath: String) {
        let image = render(size: 1024)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("icon: RENDER FAILED"); return
        }
        do {
            try png.write(to: URL(fileURLWithPath: outputPath))
            print(outputPath)
        } catch {
            print("icon: WRITE FAILED \(error)")
        }
    }

    static func render(size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            // Rounded "squircle-ish" tile with Apple-ish proportions
            let inset = size * 0.086
            let tile = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
            let radius = tile.width * 0.2237
            let tilePath = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)

            // Soft drop shadow under the tile, then a light fill on top
            NSGraphicsContext.current?.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
            shadow.shadowBlurRadius = size * 0.028
            shadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
            shadow.set()
            NSColor.white.setFill()
            tilePath.fill()
            NSGraphicsContext.current?.restoreGraphicsState()

            // Clip everything that follows to the tile
            tilePath.addClip()
            let top = OKLCH(l: 0.987, c: 0.008, h: 95).nsColor
            let bottom = OKLCH(l: 0.945, c: 0.020, h: 150).nsColor
            NSGradient(colors: [top, bottom])?.draw(in: tilePath, angle: -90)

            // Lotus placement: ~62% of the tile, vertically centered
            let lotusSpaceW = 132.0     // full-bloom bbox width in lotus units
            let lotusSpaceH = 90.0
            let scale = tile.width * 0.70 / lotusSpaceW
            let baseX = tile.midX
            let baseY = tile.minY + (tile.height - lotusSpaceH * scale) / 2

            // A breath of green glow behind the flower
            if let glow = NSGradient(colors: [
                OKLCH(l: 0.72, c: 0.13, h: 150).nsColor.withAlphaComponent(0.22),
                NSColor.clear,
            ]) {
                let center = NSPoint(x: baseX, y: baseY + 52 * scale)
                glow.draw(fromCenter: center, radius: 0,
                          toCenter: center, radius: tile.width * 0.42, options: [])
            }

            for p in petals.sorted(by: { z($0) < z($1) }) {
                drawPetal(p, baseX: baseX, baseY: baseY, scale: scale)
            }
            return true
        }
    }

    private static func drawPetal(_ p: Petal, baseX: CGFloat, baseY: CGFloat, scale: CGFloat) {
        let angle = p.angle
        let baseTangent = min(max(angle * 1.5, -94), 94)
        let length = p.length * scale
        let halfWidth = length * 0.23

        func polar(_ degrees: Double, _ r: Double) -> NSPoint {
            let rad = degrees * .pi / 180
            return NSPoint(x: sin(rad) * r, y: cos(rad) * r)   // y-up
        }
        let base = NSPoint(x: baseX, y: baseY)
        let tipV = polar(angle, length)
        let tip = NSPoint(x: base.x + tipV.x, y: base.y + tipV.y)
        let ctrlV = polar(baseTangent, length * 0.55)
        let ctrl = NSPoint(x: base.x + ctrlV.x, y: base.y + ctrlV.y)

        func spine(_ s: Double) -> NSPoint {
            let u = 1 - s
            return NSPoint(
                x: u * u * base.x + 2 * u * s * ctrl.x + s * s * tip.x,
                y: u * u * base.y + 2 * u * s * ctrl.y + s * s * tip.y
            )
        }
        func normal(_ s: Double) -> NSPoint {
            let u = 1 - s
            let dx = 2 * u * (ctrl.x - base.x) + 2 * s * (tip.x - ctrl.x)
            let dy = 2 * u * (ctrl.y - base.y) + 2 * s * (tip.y - ctrl.y)
            let len = max((dx * dx + dy * dy).squareRoot(), 0.001)
            return NSPoint(x: -dy / len, y: dx / len)
        }
        func width(_ s: Double) -> Double {
            halfWidth * pow(sin(.pi * pow(s, 0.85)), 0.9)
        }

        let steps = 48
        var left: [NSPoint] = []
        var right: [NSPoint] = []
        for i in 0...steps {
            let s = Double(i) / Double(steps)
            let pt = spine(s)
            let n = normal(s)
            let w = width(s)
            left.append(NSPoint(x: pt.x + n.x * w, y: pt.y + n.y * w))
            right.append(NSPoint(x: pt.x - n.x * w, y: pt.y - n.y * w))
        }
        let path = NSBezierPath()
        path.move(to: left[0])
        for pt in left.dropFirst() { path.line(to: pt) }
        for pt in right.reversed() { path.line(to: pt) }
        path.close()

        // Outer ring green, inner ring lotus-pink; pale at the base, deep at the tip
        let core = p.ring == 0 ? OKLCH(l: 0.60, c: 0.16, h: 150) : OKLCH(l: 0.72, c: 0.15, h: 350)
        let pale = core.lighter(0.15).softer(0.06)
        let deep = OKLCH(l: max(0, core.l - 0.03), c: core.c + 0.015, h: core.h)
        let outline = OKLCH(l: max(0, core.l - 0.12), c: core.c, h: core.h).nsColor.withAlphaComponent(0.40)

        NSGradient(colors: [pale.nsColor, deep.nsColor])?.draw(in: path, angle: 90 - angle)
        outline.setStroke()
        path.lineWidth = max(1, length * 0.025)
        path.lineJoinStyle = .round
        path.stroke()
    }
}
