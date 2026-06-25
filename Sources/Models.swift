import Foundation

public struct Repository {
    public let name: String
    public let owner: String
    public let remoteURL: String

    /// The HTTPS URL, normalised from SSH or HTTPS remote URL.
    public var httpsURL: String {
        // Already HTTPS
        if remoteURL.hasPrefix("https://") { return remoteURL }
        // SSH: git@github.com:owner/repo.git → https://github.com/owner/repo
        return "https://github.com/\(owner)/\(name)"
    }
}

public struct GitHubAccount {
    public let username: String
    public let isCurrent: Bool
}
