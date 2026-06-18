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

    /// The set shipped in the binary and shown when there's no local
    /// `quotes.txt`. PUBLIC-SAFE ONLY — famous attributions, proverbs, and
    /// Bua's own voice. Personal quotes ("said only to me", named friends,
    /// intimate) live solely in the local quotes.txt, never here.
    static let starter: [Quote] = [
        // Bua's own quiet voice
        Quote(text: "Dream big, act quick, start small, be kind.", attribution: "Søren Fuhr"),
        Quote(text: "No mud, no lotus.", attribution: nil),
        Quote(text: "Steady beats panicked.", attribution: nil),
        Quote(text: "This, too, is impermanent.", attribution: nil),
        Quote(text: "Rest is part of the work.", attribution: nil),
        Quote(text: "The lotus does not hurry, and still it blooms.", attribution: nil),
        Quote(text: "Begin again, softly.", attribution: nil),
        Quote(text: "The garden grows while you sleep.", attribution: nil),

        // Impermanence & letting go
        Quote(text: "Impermanence is inescapable. Everything vanishes.", attribution: "Buddha"),
        Quote(text: "Suffering usually relates to wanting things to be different than they are.", attribution: "Allan Lokos"),
        Quote(text: "I realize there's something incredibly honest about trees in winter, how they're experts at letting things go.", attribution: "Jeffrey McDaniel"),
        Quote(text: "The usefulness of a pot comes from its emptiness.", attribution: "Lao Tzu"),

        // Calm & presence
        Quote(text: "Speak only if it improves upon the silence.", attribution: "Gandhi"),
        Quote(text: "Worrying does not take away tomorrow's troubles, it takes away today's peace.", attribution: nil),
        Quote(text: "In the beginner's mind there are many possibilities. In the expert's there are few.", attribution: "Suzuki Roshi"),
        Quote(text: "Care about what other people think and you will always be their prisoner.", attribution: "Lao Tzu"),

        // Kindness & service
        Quote(text: "If you can help, help. If you can't help, don't hurt.", attribution: "Dalai Lama"),
        Quote(text: "Work is love made visible.", attribution: "Kahlil Gibran"),
        Quote(text: "Comparison is the thief of joy.", attribution: "Theodore Roosevelt"),
        Quote(text: "Experience joy in the happiness of others.", attribution: "David Nichtern"),

        // Courage — not failure, nightfall
        Quote(text: "Success is not final, failure is not fatal: it is the courage to continue that counts.", attribution: "Winston Churchill"),
        Quote(text: "Life shrinks or expands in proportion to one's courage.", attribution: "Anaïs Nin"),
        Quote(text: "If you're not making a mistake, it's a mistake.", attribution: "Miles Davis"),
        Quote(text: "Be kind to yourself always, even in defeat — especially in defeat!", attribution: nil),

        // Craft & simplicity
        Quote(text: "Perfection is achieved, not when there is nothing left to add, but when there is nothing left to take away.", attribution: "Antoine de Saint-Exupéry"),
        Quote(text: "Everything should be made as simple as possible, but not simpler.", attribution: nil),
        Quote(text: "The essence of strategy is choosing what not to do.", attribution: "Michael Porter"),
        Quote(text: "If you knew how much work went into it, you wouldn't call it genius.", attribution: "Michelangelo"),
        Quote(text: "We don't make mistakes. We have happy accidents.", attribution: "Bob Ross"),

        // Beginning
        Quote(text: "The best time to plant a tree was 20 years ago. The second best time is now.", attribution: "Chinese proverb"),
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
