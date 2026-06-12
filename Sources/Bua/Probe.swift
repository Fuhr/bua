import Foundation

/// `Bua --probe` — prints decoded live usage and exits.
/// Build-time verification of keychain read + endpoint + parsing, no UI.
enum Probe {
    static func run() async {
        guard let credentials = KeychainReader.read() else {
            print("probe: no credentials in keychain (service \"\(KeychainReader.service)\")")
            return
        }
        guard !credentials.isExpired else {
            print("probe: token expired \(credentials.expiresAt.formatted()) — open Claude Code to refresh it")
            return
        }
        do {
            let snapshot = try await UsageFetcher.fetch(token: credentials.accessToken)
            print("bua probe — \(Date().formatted(date: .abbreviated, time: .standard))")
            printBucket("session (5h)", snapshot.fiveHour)
            printBucket("week", snapshot.sevenDay)
            printBucket("week · opus", snapshot.sevenDayOpus)
            printBucket("week · sonnet", snapshot.sevenDaySonnet)
        } catch {
            print("probe failed: \(error)")
        }
    }

    private static func printBucket(_ name: String, _ bucket: UsageBucket?) {
        guard let bucket else {
            print("  \(name): –")
            return
        }
        let pct = bucket.utilization.map { String(format: "%.0f%%", $0) } ?? "–"
        let resets = bucket.resetsAt.map {
            RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date())
        } ?? "–"
        print("  \(name): \(pct), resets \(resets)")
    }
}
