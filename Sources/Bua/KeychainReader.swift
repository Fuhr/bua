import Foundation

/// Reads Claude Code's OAuth credentials from the login keychain.
///
/// Deliberately shells out to `/usr/bin/security` instead of calling
/// `SecItemCopyMatching`: the keychain item's partition list authorizes
/// Apple-signed tools, so the CLI reads it without a permission prompt,
/// while a direct read from an ad-hoc-signed binary would prompt on
/// every rebuild.
enum KeychainReader {
    /// Claude Code has renamed this between versions before — if reads
    /// start failing, check the current item name in Keychain Access.
    static let service = "Claude Code-credentials"

    struct Credentials {
        let accessToken: String
        let expiresAt: Date
        var isExpired: Bool { expiresAt <= Date() }
    }

    /// Returns nil on any failure — the app shows the resting state.
    /// Never touches the refresh token: refresh tokens rotate, and
    /// consuming one could invalidate Claude Code's own credentials.
    static func read() -> Credentials? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-w"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = json["claudeAiOauth"] as? [String: Any],
            let token = oauth["accessToken"] as? String,
            let expiresMs = oauth["expiresAt"] as? Double   // epoch milliseconds
        else { return nil }

        return Credentials(
            accessToken: token,
            expiresAt: Date(timeIntervalSince1970: expiresMs / 1000)
        )
    }
}
