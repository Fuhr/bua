import Foundation

struct Quote: Equatable {
    let text: String
    let attribution: String?
}

/// One quote shows under the limits each time the panel opens (click it
/// for another). Søren's collection lives in Application Support — local
/// only, never leaves the machine.
///
/// File format: entries separated by lines containing only `%`. The final
/// lines of an entry starting with `—` are the attribution. Lines starting
/// with `#` are comments. Quotes longer than `panelLimit` characters stay
/// in the file but don't rotate into the panel.
enum Quotes {
    /// A quote rotates into the panel only if it fits ~5 rendered lines
    /// (estimated from explicit line breaks plus wrap length: ~36 chars
    /// per line at 11pt in the panel's width).
    static func fitsPanel(_ quote: Quote) -> Bool {
        let estimatedLines = quote.text
            .components(separatedBy: "\n")
            .reduce(0) { $0 + max(1, Int(ceil(Double($1.count) / 36.0))) }
        return estimatedLines <= 5
    }

    static let starter: [Quote] = [
        Quote(text: "Dream big, act quick, start small, be kind.", attribution: "Søren Fuhr"),
        Quote(text: "No mud, no lotus.", attribution: nil),
        Quote(text: "Steady beats panicked.", attribution: nil),
        Quote(text: "This, too, is impermanent.", attribution: nil),
        Quote(text: "Rest is part of the work.", attribution: nil),
        Quote(text: "The lotus does not hurry, and still it blooms.", attribution: nil),
        Quote(text: "Begin again, softly.", attribution: nil),
        Quote(text: "The garden grows while you sleep.", attribution: nil),
    ]

    static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bua/quotes.txt")
    }

    static func load() -> [Quote] {
        guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { return starter }
        var quotes: [Quote] = []
        let blocks = raw
            .components(separatedBy: "\n")
            .split { $0.trimmingCharacters(in: .whitespaces) == "%" }
        for block in blocks {
            var lines = block
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.hasPrefix("#") }
            while let last = lines.last, last.isEmpty { lines.removeLast() }
            while let first = lines.first, first.isEmpty { lines.removeFirst() }

            var attribution: [String] = []
            while let last = lines.last, last.hasPrefix("—") {
                attribution.insert(
                    String(last.dropFirst()).trimmingCharacters(in: .whitespaces),
                    at: 0
                )
                lines.removeLast()
            }
            let text = lines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            quotes.append(Quote(
                text: text,
                attribution: attribution.isEmpty ? nil : attribution.joined(separator: ", ")
            ))
        }
        return quotes.isEmpty ? starter : quotes
    }

    static func random() -> Quote {
        let all = load()
        let fitting = all.filter(fitsPanel)
        return (fitting.isEmpty ? all : fitting).randomElement() ?? starter[0]
    }

    /// Creates the quotes file with the starter set so there's something
    /// to edit the first time "Edit Quotes…" is chosen.
    static func ensureFileExists() {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let header = """
        # Bua quotes — entries separated by lines containing only %
        # The final lines starting with "— " are the attribution (optional).
        # A random one shows each time the panel opens. Local only.
        """
        let body = starter
            .map { $0.text + ($0.attribution.map { "\n— \($0)" } ?? "") }
            .joined(separator: "\n%\n")
        try? (header + "\n%\n" + body + "\n")
            .write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
