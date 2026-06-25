import Foundation

/// Implements GitHub's OAuth Device Flow (RFC 8628) using URLSession.
/// No external curl binary — uses Foundation networking directly.
public struct GitHubAuth {

    private static let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    private static let tokenURL      = URL(string: "https://github.com/login/oauth/access_token")!
    private static let apiURL        = URL(string: "https://api.github.com/user")!

    private static var home: String {
        ProcessInfo.processInfo.environment["HOME"] ?? "~"
    }

    private static var configFile: String { "\(home)/.config/gitram/config" }

    // MARK: - Client ID Config

    public static var clientId: String? {
        guard let content = try? String(contentsOfFile: configFile, encoding: .utf8) else { return nil }
        for line in content.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.hasPrefix("client_id=") {
                let v = String(t.dropFirst("client_id=".count))
                return v.isEmpty ? nil : v
            }
        }
        return nil
    }

    public static func setClientId(_ id: String) {
        let dir = "\(home)/.config/gitram"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        var lines = (try? String(contentsOfFile: configFile, encoding: .utf8))?
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("client_id=") && !$0.isEmpty }
            ?? []
        lines.append("client_id=\(id)")
        try? lines.joined(separator: "\n").write(toFile: configFile, atomically: true, encoding: .utf8)
    }

    // MARK: - Device Code

    public struct DeviceCode {
        public let code: String
        public let userCode: String
        public let verificationUri: String
        public let interval: Int
    }

    /// Step 1: Request device + user code from GitHub.
    public static func requestDeviceCode(clientId: String) -> DeviceCode? {
        let body = "client_id=\(clientId)&scope=repo%20read%3Aorg"
        guard let json = post(url: deviceCodeURL, body: body) else { return nil }

        guard let deviceCode      = extractJSONValue(json, key: "device_code"),
              let userCode        = extractJSONValue(json, key: "user_code"),
              let verificationUri = extractJSONValue(json, key: "verification_uri")
        else { return nil }

        let interval = Int(extractJSONValue(json, key: "interval") ?? "5") ?? 5
        return DeviceCode(code: deviceCode, userCode: userCode,
                          verificationUri: verificationUri, interval: interval)
    }

    /// Step 2: Poll GitHub until user authorises (up to 15 minutes).
    public static func pollForToken(clientId: String, deviceCode: DeviceCode, timeout: TimeInterval = 900) -> String? {
        let grantType = "urn:ietf:params:oauth:grant-type:device_code"
        let deadline  = Date().addingTimeInterval(timeout)
        var pollInterval = deviceCode.interval

        while Date() < deadline {
            Thread.sleep(forTimeInterval: Double(pollInterval))

            let body = "client_id=\(clientId)&device_code=\(deviceCode.code)&grant_type=\(grantType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? grantType)"
            guard let json = post(url: tokenURL, body: body) else { continue }

            if let token = extractJSONValue(json, key: "access_token") {
                return token
            }

            switch extractJSONValue(json, key: "error") {
            case "authorization_pending": continue
            case "slow_down":            pollInterval += 5
            case .some(let e):           UI.printError("Auth error: \(e)"); return nil
            case .none:                  continue
            }
        }
        return nil
    }

    /// Fetches the GitHub username for the given OAuth token.
    public static func validateToken(_ token: String) -> String? {
        var request = URLRequest(url: apiURL, timeoutInterval: 20)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let json = syncFetch(request: request) else { return nil }
        return extractJSONValue(json, key: "login")
    }

    // MARK: - HTTP Helpers

    // Box for safe cross-thread state sharing (URLSession callback is on a different thread).
    private final class Box: @unchecked Sendable {
        var body: String?
        var errorDescription: String?
    }

    private static func post(url: URL, body: String) -> String? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)
        return syncFetch(request: request)
    }

    /// Performs a synchronous URLSession request.
    /// Uses DispatchGroup.wait() which blocks the calling thread while allowing
    /// URLSession's internal callback queue (a different thread) to fire normally.
    private static func syncFetch(request: URLRequest) -> String? {
        let box   = Box()
        let group = DispatchGroup()

        group.enter()
        URLSession.shared.dataTask(with: request) { data, _, error in
            box.body             = data.flatMap { String(data: $0, encoding: .utf8) }
            box.errorDescription = error?.localizedDescription
            group.leave()
        }.resume()

        let timeout = group.wait(timeout: .now() + 25)
        if timeout == .timedOut {
            fputs("[gitram] network: request timed out (25s)\n", stderr)
            return nil
        }
        if let err = box.errorDescription {
            fputs("[gitram] network error: \(err)\n", stderr)
        }
        return box.body
    }

    // MARK: - JSON Helper

    public static func extractJSONValue(_ json: String, key: String) -> String? {
        let quotedPattern = "\"\(key)\"\\s*:\\s*\"([^\"]+)\""
        if let range = json.range(of: quotedPattern, options: .regularExpression) {
            let parts = String(json[range]).components(separatedBy: "\"")
            if parts.count >= 4 { return parts[parts.count - 2] }
        }
        let numberPattern = "\"\(key)\"\\s*:\\s*([0-9]+)"
        if let range = json.range(of: numberPattern, options: .regularExpression) {
            return String(json[range])
                .components(separatedBy: ":")
                .last?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}

/// Global helper used in main.swift.
func extractJSONGlobal(from json: String, key: String) -> String? {
    GitHubAuth.extractJSONValue(json, key: key)
}
