import Foundation

/// One quote shows under the limits each time the panel opens.
/// Søren's own collection lives in Application Support — local only,
/// never leaves the machine. Falls back to the starter set.
enum Quotes {
    static let starter: [String] = [
        "Dream big, act quick, start small, be kind.",
        "No mud, no lotus.",
        "Steady beats panicked.",
        "This, too, is impermanent.",
        "Rest is part of the work.",
        "The lotus does not hurry, and still it blooms.",
        "Begin again, softly.",
        "The garden grows while you sleep.",
    ]

    static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bua/quotes.txt")
    }

    static func load() -> [String] {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return starter }
        let lines = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        return lines.isEmpty ? starter : lines
    }

    static func random() -> String {
        load().randomElement() ?? starter[0]
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
        # Bua quotes — one per line, lines starting with # are ignored.
        # A random one shows each time the panel opens. Local only.

        """
        try? (header + starter.joined(separator: "\n") + "\n")
            .write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
