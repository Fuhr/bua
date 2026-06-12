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
                model.quote = "No mud, no lotus."
                rendered.append(write(model: model, dark: dark, name: String(format: "bua-%@-%03d", dark ? "dark" : "light", Int(t * 100)), to: dir))
            }
            let resting = UsageModel()
            resting.previewResting()
            resting.quote = "The garden grows while you sleep."
            rendered.append(write(model: resting, dark: dark, name: "bua-\(dark ? "dark" : "light")-resting", to: dir))
        }
        print(rendered.joined(separator: "\n"))
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
