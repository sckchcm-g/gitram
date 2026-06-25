import Foundation

/// Thin wrapper around the external git-credential-manager binary.
/// GitRAM no longer uses GCM for account listing or credential resolution —
/// it uses its own AccountStore + TokenStore instead.
/// GCM is only used here to erase stale repo-specific cache entries during a switch.
public struct GCM {

    // MARK: - Detection

    public static func locate() -> String? {
        let candidates = [
            "/usr/local/bin/git-credential-manager",
            "/opt/homebrew/bin/git-credential-manager"
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }
        let out = Shell.run("which git-credential-manager")
        if out.succeeded {
            let p = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !p.isEmpty { return p }
        }
        return nil
    }

    public static func isInstalled() -> Bool { locate() != nil }

    public static func version() -> String? {
        guard let gcm = locate() else { return nil }
        let out = Shell.run("\(gcm) --version")
        return out.succeeded ? out.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }

    // MARK: - Account Listing (best-effort, used only for migration)

    /// Lists accounts known to GCM. Used only to surface accounts not yet in GitRAM's own store.
    public static func listAccounts() -> [String] {
        guard let gcm = locate() else { return [] }
        let out = Shell.run("\(gcm) github list")
        guard out.succeeded else { return [] }
        return out.stdout
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Repo Credential Cleanup

    /// Erases ONLY the repo-specific cached credential entry from GCM.
    /// Never erases the global account entry — that would remove the account from GCM entirely.
    public static func eraseRepositoryCredential(owner: String, name: String, workingDirectory: String) {
        guard let gcm = locate() else { return }
        for path in ["\(owner)/\(name).git", "\(owner)/\(name)"] {
            let input = "protocol=https\nhost=github.com\npath=\(path)\n\n"
            Shell.run("\(gcm) erase", input: input, workingDirectory: workingDirectory)
        }
    }
}
