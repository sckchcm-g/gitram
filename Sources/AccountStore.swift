import Foundation

/// Manages the list of known GitHub accounts for GitRAM.
/// Stored at ~/.config/gitram/accounts — one username per line.
public struct AccountStore {
    private static var configDir: String {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? "~"
        return "\(home)/.config/gitram"
    }

    private static var accountsFile: String { "\(configDir)/accounts" }

    /// All accounts GitRAM knows about.
    public static func all() -> [String] {
        guard let content = try? String(contentsOfFile: accountsFile, encoding: .utf8) else { return [] }
        return content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Adds a username to the account list (no-op if already present).
    public static func add(_ username: String) {
        var accounts = all()
        guard !accounts.contains(username) else { return }
        accounts.append(username)
        persist(accounts)
    }

    /// Removes a username from the account list.
    public static func remove(_ username: String) {
        persist(all().filter { $0 != username })
    }

    public static func contains(_ username: String) -> Bool {
        all().contains(username)
    }

    private static func persist(_ accounts: [String]) {
        try? FileManager.default.createDirectory(
            atPath: configDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? accounts.joined(separator: "\n").write(
            toFile: accountsFile,
            atomically: true,
            encoding: .utf8
        )
    }
}
