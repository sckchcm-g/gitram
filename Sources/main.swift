import Foundation

// MARK: - Command Routing

let args = Array(CommandLine.arguments.dropFirst())
let command = args.first ?? "switch"

switch command {
case "switch", "":  cmdSwitch()
case "status":      cmdStatus()
case "accounts":    cmdAccounts()
case "add":         cmdAdd(username: args.count > 1 ? args[1] : nil)
case "remove":      cmdRemove(username: args.count > 1 ? args[1] : nil)
case "setup":       cmdSetup(clientId: args.count > 1 ? args[1] : nil)
case "doctor":      cmdDoctor()
// Git credential helper protocol (called by git internally)
case "get":         credentialGet()
case "store":       credentialStore()
case "erase":       credentialErase()
case "help", "--help", "-h": printHelp()
default:
    UI.printError("Unknown command: \(command)")
    print()
    printHelp()
    exit(1)
}

// MARK: - Help

func printHelp() {
    UI.printHeader()
    print()
    print("  \(bold("Usage:"))  gitram [command]")
    print()
    print("  \(cyan("switch"))     Switch the GitHub account for this repository  \(dim("(default)"))")
    print("  \(cyan("add"))        Authenticate a GitHub account (browser, once)")
    print("  \(cyan("remove"))     Remove a GitHub account from GitRAM")
    print("  \(cyan("accounts"))   List all GitHub accounts")
    print("  \(cyan("status"))     Show repository and credential status")
    print("  \(cyan("setup"))      Configure GitRAM OAuth App client ID")
    print("  \(cyan("doctor"))     Check Git and credential health")
    print("  \(cyan("help"))       Show this help message")
    print()
    print("  \(dim("First time setup:"))")
    print("  \(dim("  1. gitram setup             → configure OAuth App"))")
    print("  \(dim("  2. gitram add               → authenticate accounts"))")
    print("  \(dim("  3. git config --global credential.helper /usr/local/bin/gitram"))")
    print()
}

// MARK: - ANSI helpers (used only in main.swift)
func bold(_ s: String)  -> String { "\u{001B}[1m\(s)\u{001B}[0m" }
func cyan(_ s: String)  -> String { "\u{001B}[36m\(s)\u{001B}[0m" }
func dim(_ s: String)   -> String { "\u{001B}[90m\(s)\u{001B}[0m" }
func green(_ s: String) -> String { "\u{001B}[32m\(s)\u{001B}[0m" }
func yellow(_ s: String)-> String { "\u{001B}[33m\(s)\u{001B}[0m" }

// MARK: - gitram setup

func cmdSetup(clientId: String?) {
    UI.printHeader()
    print()

    if let existingId = GitHubAuth.clientId {
        print("  Current Client ID: \(dim(existingId))")
        print()
    }

    if let id = clientId, !id.isEmpty {
        GitHubAuth.setClientId(id)
        UI.printSuccess("Client ID saved.")
        print()
        print(dim("  Next steps:"))
        print(dim("    gitram add <username>"))
        print(dim("    git config --global credential.helper /usr/local/bin/gitram"))
        print()
        return
    }

    // Interactive setup
    print(bold("  GitHub OAuth App Setup"))
    print()
    print("  GitRAM needs a GitHub OAuth App to authenticate without a browser each time.")
    print()
    print("  \(bold("Step 1:")) Open this URL in your browser:")
    print("  \(cyan("  https://github.com/settings/developers"))")
    print()
    print("  \(bold("Step 2:")) Click \(bold("\"New OAuth App\"")) and fill in:")
    print("  \(dim("  Application name:"))     GitRAM")
    print("  \(dim("  Homepage URL:"))         https://github.com")
    print("  \(dim("  Callback URL:"))         http://localhost")
    print()
    print("  \(bold("Step 3:")) Copy the \(bold("Client ID")) (NOT the secret) and paste it below.")
    print()
    print(bold("  Client ID:"), terminator: " ")
    fflush(stdout)

    guard let id = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
        UI.printError("No client ID entered.")
        exit(1)
    }

    GitHubAuth.setClientId(id)
    print()
    UI.printSuccess("Client ID saved.")
    print()
    print(dim("  Next: gitram add <github-username>"))
    print()
}

// MARK: - gitram add

func cmdAdd(username: String?) {
    UI.printHeader()
    print()

    let displayName = username.map { bold($0) } ?? "GitHub account"
    print("  Adding \(displayName)")
    print()

    print("  How do you want to authenticate?")
    print()
    print("  \(dim("1.")) \(bold("Browser login"))  \(dim("(OAuth device flow — open browser once, then never again)"))")
    print("  \(dim("2.")) \(bold("Personal Access Token"))  \(dim("(paste a PAT from github.com/settings/tokens)"))")
    print()
    print(cyan("> "), terminator: "")
    fflush(stdout)

    let choice = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    switch choice {
    case "1":
        guard let clientId = GitHubAuth.clientId else {
            print()
            UI.printWarning("Browser login requires a one-time OAuth App setup.")
            print()
            print(dim("  GitRAM needs a Client ID so GitHub knows which app is requesting access."))
            print(dim("  This is a GitHub requirement for all browser-based logins."))
            print()
            print("  \(bold("Option A:")) Create a free GitHub OAuth App (2 min):")
            print(dim("    gitram setup"))
            print()
            print("  \(bold("Option B:")) Use a PAT instead (30 sec, no app needed):")
            print(dim("    gitram add  →  choose option 2"))
            print(dim("    https://github.com/settings/tokens"))
            exit(1)
        }
        cmdAddBrowser(username: username, clientId: clientId)
    case "2":
        print()
        cmdAddPAT(username: username)
    default:
        UI.printDim("Cancelled.")
        exit(0)
    }
}

// MARK: - gitram add (browser / OAuth device flow)

func cmdAddBrowser(username: String?, clientId: String) {
    print()
    let displayName = username.map { " \(bold($0))" } ?? ""
    print("  Authenticating GitHub account\(displayName) via browser...")
    print()

    UI.printDim("  Requesting authentication code...")
    guard let deviceCode = GitHubAuth.requestDeviceCode(clientId: clientId) else {
        UI.printError("Failed to reach GitHub. Check your network connection.")
        exit(1)
    }

    print()
    print("  \(bold("Open this URL in your browser:"))")
    print("  \(cyan("  \(deviceCode.verificationUri)"))")
    print()
    print("  \(bold("Enter this code:"))")
    print()
    print("  \(ANSI.color(ANSI.magenta + ANSI.bold, "  " + deviceCode.userCode + "  "))")
    print()
    print(dim("  Waiting... (15 min timeout, Ctrl+C to cancel)"))
    print()

    guard let token = GitHubAuth.pollForToken(clientId: clientId, deviceCode: deviceCode) else {
        UI.printError("Authentication timed out or was denied.")
        exit(1)
    }

    UI.printDim("  Validating token...")
    let actualUsername = GitHubAuth.validateToken(token) ?? username ?? ""

    guard !actualUsername.isEmpty else {
        UI.printError("Could not determine GitHub username from token.")
        exit(1)
    }

    if let requested = username, requested.lowercased() != actualUsername.lowercased() {
        UI.printWarning("Authenticated as '\(actualUsername)' (not '\(requested)')")
    }

    AccountStore.add(actualUsername)
    _ = TokenStore.store(username: actualUsername, token: token)

    print()
    UI.printSuccess("Authenticated as \(bold(actualUsername))")
    print()

    let helper = Git.configValue("credential.helper") ?? ""
    if !helper.contains("gitram") {
        print(dim("  Set GitRAM as credential helper:"))
        print(dim("    git config --global credential.helper /usr/local/bin/gitram"))
        print()
    }
}

// MARK: - gitram add --pat (manual PAT fallback)

func cmdAddPAT(username: String?) {
    var user = username ?? ""
    if user.isEmpty {
        print(bold("GitHub username:"), terminator: " ")
        fflush(stdout)
        user = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    guard !user.isEmpty else {
        UI.printError("Username cannot be empty.")
        exit(1)
    }

    print()
    print(dim("  Generate a PAT at: https://github.com/settings/tokens"))
    print(dim("  Required scopes: repo, read:org"))
    print()

    guard let token = UI.readSecret(prompt: "Personal Access Token:"), !token.isEmpty else {
        UI.printError("Token cannot be empty.")
        exit(1)
    }

    // Optional: validate
    UI.printDim("  Validating...")
    let actual = GitHubAuth.validateToken(token)
    let finalUser = actual ?? user

    if let a = actual, a.lowercased() != user.lowercased() {
        UI.printWarning("Token belongs to '\(a)', not '\(user)'.")
    }

    AccountStore.add(finalUser)
    _ = TokenStore.store(username: finalUser, token: token)

    print()
    UI.printSuccess("Account '\(bold(finalUser))' added.")
    print()
}

// MARK: - gitram remove

func cmdRemove(username: String?) {
    UI.printHeader()

    let accounts = AccountStore.all()
    guard !accounts.isEmpty else {
        print()
        UI.printWarning("No accounts configured. Run: gitram add")
        exit(0)
    }

    var user = username ?? ""
    if user.isEmpty {
        print()
        UI.printSection("Accounts")
        for (i, a) in accounts.enumerated() { print("  \(dim("\(i+1)."))")
            print("     \(a)") }
        print()
        print(bold("Username to remove:"), terminator: " ")
        fflush(stdout)
        user = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    guard !user.isEmpty, accounts.contains(user) else {
        UI.printError("Account '\(user)' not found.")
        exit(1)
    }

    AccountStore.remove(user)
    TokenStore.delete(username: user)
    print()
    UI.printSuccess("Removed '\(user)'.")
    print()
}

// MARK: - gitram accounts

func cmdAccounts() {
    UI.printHeader()
    UI.printSection("GitHub Accounts")

    let accounts = AccountStore.all()
    if accounts.isEmpty {
        print()
        UI.printDim("  No accounts configured.")
        UI.printDim("  Run: gitram add")
    } else {
        for (i, account) in accounts.enumerated() {
            let hasToken = TokenStore.hasToken(for: account)
            let tokenStatus = hasToken
                ? ANSI.color(ANSI.green, "● authenticated")
                : ANSI.color(ANSI.yellow, "○ no token — run: gitram add \(account)")
            print()
            print("  \(dim("\(i+1)."))")
            print("     \(bold(account))")
            print("     \(tokenStatus)")
        }
    }
    print()
}

// MARK: - gitram status

func cmdStatus() {
    UI.printHeader()

    guard let repoRoot = Git.detectRepositoryRoot() else {
        UI.printError("Not inside a Git repository.")
        exit(1)
    }
    guard let remoteURL = Git.getRemoteURL(),
          let repo = Git.parseRepository(from: remoteURL) else {
        UI.printError("No origin remote configured or could not parse URL.")
        exit(1)
    }

    let currentAccount = Git.getCurrentAccount(workingDirectory: repoRoot)
    let branch         = Git.getCurrentBranch() ?? "unknown"
    let credHelper     = Git.configValue("credential.helper") ?? "none"
    let useHttpPath    = Git.configValue("credential.https://github.com.usehttppath") ?? "not set"

    UI.printSection("Repository")
    UI.printRow(label: "Name",    value: repo.name)
    UI.printRow(label: "Owner",   value: repo.owner)
    UI.printRow(label: "Branch",  value: branch)
    UI.printRow(label: "Remote",  value: repo.remoteURL)

    UI.printSection("Credentials")
    UI.printRow(label: "Active account",    value: currentAccount.map { green($0) } ?? dim("none"))
    UI.printRow(label: "Credential helper", value: credHelper)
    UI.printRow(label: "useHttpPath",       value: useHttpPath)

    UI.printSection("GitRAM Accounts")
    let accounts = AccountStore.all()
    if accounts.isEmpty {
        UI.printDim("  No accounts. Run: gitram add")
    } else {
        for a in accounts {
            let isCurrent = (a == currentAccount)
            let mark = isCurrent ? green("✓") : " "
            let hasToken = TokenStore.hasToken(for: a)
            let tMark = hasToken ? "" : ANSI.color(ANSI.yellow, " (no token)")
            print("  \(mark)  \(a)\(tMark)")
        }
    }
    print()
}

// MARK: - gitram doctor

func cmdDoctor() {
    UI.printHeader()
    UI.printSection("System Health")

    let gitVersion = Git.version()
    UI.printCheck(label: "Git installed",           ok: gitVersion != nil, detail: gitVersion ?? "")
    UI.printCheck(label: "GCM installed (optional)",ok: GCM.isInstalled(), detail: GCM.version() ?? "not found")

    let repoRoot = Git.detectRepositoryRoot()
    UI.printCheck(label: "Inside a Git repository", ok: repoRoot != nil)

    let helper = Git.configValue("credential.helper") ?? ""
    var helperOk = false
    var helperDetail = helper.isEmpty ? "not set" : helper
    
    if !helper.isEmpty {
        if helper.starts(with: "/") {
            helperOk = FileManager.default.fileExists(atPath: helper)
            if !helperOk {
                helperDetail = "executable not found at \(helper)"
            }
        } else if helper == "gitram" {
            let whichOut = Shell.run("which git-credential-gitram")
            if whichOut.succeeded && !whichOut.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                helperOk = true
            } else {
                helperDetail = "git-credential-gitram not found in PATH"
            }
        } else {
            helperOk = helper.contains("gitram")
        }
    }
    UI.printCheck(label: "credential.helper configured", ok: helperOk, detail: helperDetail)

    let clientId = GitHubAuth.clientId
    UI.printCheck(label: "OAuth App configured", ok: clientId != nil, detail: clientId.map { String($0.prefix(8)) + "..." } ?? "run: gitram setup")

    let accounts = AccountStore.all()
    UI.printCheck(label: "GitRAM accounts", ok: !accounts.isEmpty,
                  detail: accounts.isEmpty ? "run: gitram add" : accounts.joined(separator: ", "))

    for a in accounts {
        UI.printCheck(label: "  Token: \(a)", ok: TokenStore.hasToken(for: a))
    }

    if let root = repoRoot {
        let account = Git.getCurrentAccount(workingDirectory: root)
        UI.printCheck(label: "Active account set", ok: account != nil, detail: account ?? "none")
    }
    
    if !helperOk {
        print()
        UI.printWarning("Credential helper is not configured properly.")
        print(dim("  To fix, run either of these commands:"))
        print(bold("    git config --global credential.helper /usr/local/bin/gitram"))
        print(dim("  OR (to keep helper name as 'gitram'):"))
        print(bold("    sudo ln -sf /usr/local/bin/gitram /usr/local/bin/git-credential-gitram"))
    }
    print()
}

// MARK: - gitram switch (default)

func cmdSwitch() {
    UI.printHeader()

    guard let repoRoot = Git.detectRepositoryRoot() else {
        UI.printError("Not inside a Git repository.")
        exit(1)
    }
    guard let remoteURL = Git.getRemoteURL(),
          let repo = Git.parseRepository(from: remoteURL) else {
        UI.printError("No origin remote or could not parse URL.")
        exit(1)
    }

    // Own store first, then surface any GCM accounts for migration
    var accounts = AccountStore.all()
    for a in GCM.listAccounts() where !accounts.contains(a) { accounts.append(a) }

    guard !accounts.isEmpty else {
        UI.printError("No GitHub accounts configured.")
        print()
        UI.printDim("  Run: gitram add")
        exit(1)
    }

    let currentAccount = Git.getCurrentAccount(workingDirectory: repoRoot)

    UI.printSection("Repository")
    print("  \(bold(repo.name))  \(dim(repo.owner))")

    UI.printSection("Current Account")
    if let current = currentAccount {
        let hasToken = TokenStore.hasToken(for: current)
        let note = hasToken ? "" : dim("  ⚠ no token — run: gitram add \(current)")
        print("  \(green("✓"))  \(bold(current))\(note)")
    } else {
        UI.printDim("  None")
    }

    UI.printSection("Select Account")
    guard let selectedIndex = UI.selectAccount(accounts: accounts, currentAccount: currentAccount) else {
        UI.printDim("Cancelled.")
        exit(0)
    }

    let selected = accounts[selectedIndex]

    if selected == currentAccount {
        UI.printSuccess("Already using \(selected). Nothing to do.")
        exit(0)
    }

    // Require token for selected account
    if !TokenStore.hasToken(for: selected) {
        print()
        UI.printWarning("No token for '\(selected)'.")
        print(dim("  Run: gitram add \(selected)"))
        exit(1)
    }

    // Switch: set local git config only — no browser, no GCM call
    print()
    UI.printDim("  Updating local git config...")
    guard Git.setLocalCredentialUsername(selected, workingDirectory: repoRoot) else {
        UI.printError("Failed to update git config.")
        exit(1)
    }

    // Clear stale GCM repo cache (best-effort, doesn't matter if GCM is absent)
    UI.printDim("  Clearing cached repo credential...")
    GCM.eraseRepositoryCredential(owner: repo.owner, name: repo.name, workingDirectory: repoRoot)

    // Verify
    let verified = Git.getCurrentAccount(workingDirectory: repoRoot)
    print()
    if verified == selected {
        UI.printSuccess("Switched to \(bold(selected))")
    } else {
        UI.printWarning("Switch may not have completed. Run: gitram status")
    }
    print()
}

// MARK: - Git Credential Helper Protocol
// Registered via: git config --global credential.helper gitram
// Git calls gitram get / store / erase with key=value on stdin.

func parseCredentialInput() -> [String: String] {
    var result: [String: String] = [:]
    while let line = readLine(), !line.isEmpty {
        let parts = line.split(separator: "=", maxSplits: 1)
        if parts.count == 2 { result[String(parts[0])] = String(parts[1]) }
    }
    return result
}

func credentialGet() {
    let input = parseCredentialInput()
    guard input["host"]?.contains("github.com") == true else { exit(1) }

    var username = input["username"] ?? ""

    // Priority 1: username provided by git in the credential protocol input
    if username.isEmpty {
        // Priority 2: detect repo root via git rev-parse (works even if CWD ≠ repo root)
        let repoRoot = Git.detectRepositoryRoot()
        let cwd = repoRoot ?? FileManager.default.currentDirectoryPath
        username = Git.getCurrentAccount(workingDirectory: cwd) ?? ""
    }

    // Priority 3: global credential.username (covers repos without a local override)
    if username.isEmpty {
        username = Git.configValue("credential.username") ?? ""
    }

    // Priority 4: last resort — first account that actually has a stored token
    if username.isEmpty {
        username = AccountStore.all().first(where: { TokenStore.hasToken(for: $0) }) ?? ""
    }

    guard !username.isEmpty, let token = TokenStore.retrieve(username: username) else { exit(1) }

    if let proto = input["protocol"] { print("protocol=\(proto)") }
    if let host  = input["host"]     { print("host=\(host)") }
    print("username=\(username)")
    print("password=\(token)")
}

func credentialStore() {
    let input = parseCredentialInput()
    guard input["host"]?.contains("github.com") == true,
          let username = input["username"], !username.isEmpty,
          let password = input["password"], !password.isEmpty else { return }
    AccountStore.add(username)
    TokenStore.store(username: username, token: password)
}

func credentialErase() {
    let input = parseCredentialInput()
    guard input["host"]?.contains("github.com") == true,
          let username = input["username"], !username.isEmpty else { return }
    TokenStore.delete(username: username)
}
