import Foundation

/// Stores and retrieves GitHub Personal Access Tokens from the macOS Keychain.
/// Uses the `gitram` service name so entries are isolated from GCM.
/// Tokens are never logged or printed.
public struct TokenStore {
    private static let service = "gitram"

    /// Stores a PAT in the Keychain for the given GitHub username.
    /// Uses Process directly (not a shell string) to keep the token out of the process table.
    @discardableResult
    public static func store(username: String, token: String) -> Bool {
        // Remove any existing entry first
        delete(username: username)
        let result = Shell.runArgs([
            "/usr/bin/security", "add-generic-password",
            "-s", service,
            "-a", username,
            "-w", token
        ])
        return result.succeeded
    }

    /// Retrieves the stored PAT for a username. Returns nil if not found.
    public static func retrieve(username: String) -> String? {
        let result = Shell.runArgs([
            "/usr/bin/security", "find-generic-password",
            "-s", service,
            "-a", username,
            "-w"
        ])
        guard result.succeeded else { return nil }
        let token = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }

    /// Removes the stored PAT for a username.
    public static func delete(username: String) {
        Shell.runArgs([
            "/usr/bin/security", "delete-generic-password",
            "-s", service,
            "-a", username
        ])
    }

    /// Returns true if a token exists in the Keychain for this username.
    public static func hasToken(for username: String) -> Bool {
        retrieve(username: username) != nil
    }
}
