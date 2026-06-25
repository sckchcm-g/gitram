import Foundation

// MARK: - ANSI Codes

enum ANSI {
    static let reset   = "\u{001B}[0m"
    static let bold    = "\u{001B}[1m"
    static let dim     = "\u{001B}[2m"
    static let red     = "\u{001B}[31m"
    static let green   = "\u{001B}[32m"
    static let yellow  = "\u{001B}[33m"
    static let cyan    = "\u{001B}[36m"
    static let magenta = "\u{001B}[35m"
    static let gray    = "\u{001B}[90m"

    static func color(_ code: String, _ text: String) -> String {
        "\(code)\(text)\(reset)"
    }
}

// MARK: - UI

public struct UI {

    // MARK: Header
    public static func printHeader() {
        let bar = ANSI.color(ANSI.magenta + ANSI.bold, "──────────────────────────")
        print(bar)
        print(ANSI.color(ANSI.magenta + ANSI.bold, "  GitRAM  "))
        print(bar)
    }

    // MARK: Section Labels
    public static func printSection(_ title: String) {
        print()
        print(ANSI.color(ANSI.cyan + ANSI.bold, title))
    }

    // MARK: Status
    public static func printSuccess(_ message: String) { print(ANSI.color(ANSI.green, "✓ ") + message) }
    public static func printWarning(_ message: String) { print(ANSI.color(ANSI.yellow, "⚠ ") + message) }
    public static func printError(_ message: String)   { print(ANSI.color(ANSI.red,   "✗ ") + message) }
    public static func printInfo(_ message: String)    { print(message) }
    public static func printDim(_ message: String)     { print(ANSI.color(ANSI.gray, message)) }
    public static func printBold(_ message: String)    { print(ANSI.color(ANSI.bold, message)) }

    // MARK: Key-Value Row
    public static func printRow(label: String, value: String, labelWidth: Int = 20) {
        let padded = (label + ":").padding(toLength: labelWidth, withPad: " ", startingAt: 0)
        print("  \(ANSI.color(ANSI.gray, padded)) \(value)")
    }

    // MARK: Doctor Check Row
    public static func printCheck(label: String, ok: Bool, detail: String = "") {
        let icon  = ok ? ANSI.color(ANSI.green, "✓") : ANSI.color(ANSI.red, "✗")
        let state = ok ? ANSI.color(ANSI.green, "ok")   : ANSI.color(ANSI.red, "fail")
        let extra = detail.isEmpty ? "" : "  \(ANSI.color(ANSI.gray, detail))"
        print("  \(icon)  \(label.padding(toLength: 32, withPad: " ", startingAt: 0))\(state)\(extra)")
    }

    // MARK: Divider
    public static func printDivider() {
        print(ANSI.color(ANSI.gray, "  ──────────────────────────"))
    }

    // MARK: Account Menu
    /// Renders numbered account list and reads a selection.
    /// Returns the 0-based index of the chosen account, or nil to cancel.
    public static func selectAccount(accounts: [String], currentAccount: String?) -> Int? {
        for (i, account) in accounts.enumerated() {
            let isCurrent = (account == currentAccount)
            let number = ANSI.color(ANSI.gray, "\(i + 1).")
            let hasToken = TokenStore.hasToken(for: account)
            let tokenMark = hasToken ? "" : ANSI.color(ANSI.yellow, " (no token)")
            if isCurrent {
                let mark = ANSI.color(ANSI.green, "✓")
                print("  \(number) \(mark) \(ANSI.color(ANSI.green + ANSI.bold, account))\(tokenMark)  \(ANSI.color(ANSI.gray, "(current)"))")
            } else {
                print("  \(number)   \(account)\(tokenMark)")
            }
        }
        print()
        print(ANSI.color(ANSI.bold, "Select account") + ANSI.color(ANSI.gray, " (number, or Enter to cancel):"))
        print(ANSI.color(ANSI.cyan, "> "), terminator: "")
        fflush(stdout)

        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !input.isEmpty,
              let choice = Int(input),
              choice > 0, choice <= accounts.count
        else { return nil }

        return choice - 1
    }

    // MARK: Hidden Password Input
    /// Reads a line from stdin with terminal echo disabled (for PAT input).
    public static func readSecret(prompt: String) -> String? {
        print(ANSI.color(ANSI.bold, prompt), terminator: " ")
        fflush(stdout)
        Shell.run("stty -echo")
        let value = readLine()
        Shell.run("stty echo")
        print() // newline after hidden input
        return value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
