import SwiftUI
import AppKit

/// `Bua --snapshot [dir]` — renders the panel offscreen at several points
/// of the day, light + dark, plus the resting state. Design review without
/// screen-recording permission; the frosted NSVisualEffectView layer can't
/// render offscreen, so a desktop-ish backdrop stands in behind the tint.
@MainActor
enum Snapshot {
    static func run(outputDir: String) {
        let dir = URL(fileURLWithPath: outputDir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var rendered: [String] = []
        for dark in [false, true] {
            for t in [0.0, 0.30, 0.55, 0.78, 1.0] {
                let model = UsageModel()
                model.previewBlooming(session: t, weekly: 0.48)
                model.quote = Quote(
                    text: "Comparison is the thief of joy.",
                    attribution: "Theodore Roosevelt"
                )
                rendered.append(write(model: model, dark: dark, name: String(format: "bua-%@-%03d", dark ? "dark" : "light", Int(t * 100)), to: dir))
            }
            let resting = UsageModel()
            resting.previewResting()
            // Long fixture: verifies a 5-line quote fits without truncation
            resting.quote = Quote(
                text: "Happiness lies in making others happy, in forsaking self-interest to bring joy to others. If each one would do that, then everyone would be happy; and all would be taken care of.",
                attribution: "Paramahansa Yogananda"
            )
            rendered.append(write(model: resting, dark: dark, name: "bua-\(dark ? "dark" : "light")-resting", to: dir))
        }
        rendered.append(contentsOf: writeGlyphs(to: dir))
        print(rendered.joined(separator: "\n"))
    }

    /// The 18px menu-bar glyph, drawn 4× for review.
    private static func writeGlyphs(to dir: URL) -> [String] {
        var written: [String] = []
        for openness in [1.0, 0.5, 0.0] {
            let glyph = StatusController.glyph(openness: openness)
            let big = NSImage(size: NSSize(width: 90, height: 90), flipped: false) { rect in
                NSColor.white.setFill()
                rect.fill()
                glyph.draw(in: NSRect(x: 9, y: 9, width: 72, height: 72))
                return true
            }
            let name = String(format: "bua-glyph-%03d", Int(openness * 100))
            let url = dir.appendingPathComponent("\(name).png")
            if let tiff = big.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
                written.append(url.path)
            }
        }
        return written
    }

    private static func write(model: UsageModel, dark: Bool, name: String, to dir: URL) -> String {
        let backdrop = dark
            ? Color(.sRGB, red: 0.13, green: 0.14, blue: 0.16)
            : Color(.sRGB, red: 0.78, green: 0.80, blue: 0.78)
        let view = ZStack {
            backdrop
            PanelContentView(model: model, offscreenChrome: true)
                .padding(20)
        }
        .environment(\.colorScheme, dark ? .dark : .light)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let url = dir.appendingPathComponent("\(name).png")
        guard
            let image = renderer.nsImage,
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let png = rep.representation(using: .png, properties: [:])
        else { return "\(name): RENDER FAILED" }
        do {
            try png.write(to: url)
            return url.path
        } catch {
            return "\(name): WRITE FAILED \(error)"
        }
    }
}
