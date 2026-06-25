import Foundation

public struct Git {
    // MARK: - Repository Detection

    /// Returns the absolute path to the repository root, or nil if not inside one.
    public static func detectRepositoryRoot() -> String? {
        let out = Shell.run("git rev-parse --show-toplevel")
        guard out.succeeded else { return nil }
        let path = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    /// Returns the HTTPS or SSH URL of the `origin` remote, or nil.
    public static func getRemoteURL() -> String? {
        let out = Shell.run("git remote get-url origin")
        guard out.succeeded else { return nil }
        let url = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return url.isEmpty ? nil : url
    }

    /// Returns the current branch name, or nil.
    public static func getCurrentBranch() -> String? {
        let out = Shell.run("git rev-parse --abbrev-ref HEAD")
        guard out.succeeded else { return nil }
        let branch = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return branch.isEmpty ? nil : branch
    }

    // MARK: - URL Parsing

    /// Parses owner and name out of an HTTPS or SSH remote URL.
    public static func parseRepository(from remoteURL: String) -> Repository? {
        var urlStr = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlStr.hasSuffix("/") { urlStr.removeLast() }
        if urlStr.hasSuffix(".git") { urlStr = String(urlStr.dropLast(4)) }

        // Normalise SSH (git@github.com:owner/repo) → https://github.com/owner/repo
        let normalized = urlStr.replacingOccurrences(of: ":", with: "/")
        let parts = normalized.split(separator: "/")

        guard parts.count >= 2 else { return nil }

        let name  = String(parts[parts.count - 1])
        let owner = String(parts[parts.count - 2])

        return Repository(name: name, owner: owner, remoteURL: remoteURL)
    }

    // MARK: - Credential Account Detection

    /// Returns the account that Git will actually use for this repository.
    ///
    /// The canonical source of truth is `git config credential.username`, which
    /// respects Git's normal config cascade (local .git/config → global ~/.gitconfig).
    /// This matches exactly what GCM will resolve when `git pull` / `git push` run.
    ///
    /// Keychain queries are unreliable for this purpose because:
    ///   1. GCM may use generic keychain entries that aren't repo-specific.
    ///   2. After a switch, the old keychain entry may still exist until GCM evicts it.
    ///   3. `security find-internet-password` returns the *first* matching entry,
    ///      which is not necessarily the active one.
    public static func getCurrentAccount(workingDirectory: String) -> String? {
        // Priority 1: local repo config (set by `gitram switch`)
        let local = Shell.run("git config --local credential.username", workingDirectory: workingDirectory)
        if local.succeeded {
            let v = local.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { return v }
        }

        // Priority 2: global git config
        let global = Shell.run("git config --global credential.username")
        if global.succeeded {
            let v = global.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { return v }
        }

        return nil
    }

    // MARK: - Git / GCM Config

    /// Reads a single git config value. Returns nil if not set.
    public static func configValue(_ key: String, workingDirectory: String? = nil) -> String? {
        let out = Shell.run("git config \(key)", workingDirectory: workingDirectory)
        guard out.succeeded else { return nil }
        let v = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }

    /// Sets `credential.username` in the local repository config.
    @discardableResult
    public static func setLocalCredentialUsername(_ username: String, workingDirectory: String) -> Bool {
        Shell.run("git config credential.username \(username)", workingDirectory: workingDirectory).succeeded
    }

    /// Returns the version string of git, or nil.
    public static func version() -> String? {
        let out = Shell.run("git --version")
        guard out.succeeded else { return nil }
        return out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
