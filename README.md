# GitRAM

Git Repository Account Manager (GitRAM) is a lightweight terminal wrapper around Git and Git Credential Manager (GCM) for macOS. It simplifies switching between multiple GitHub accounts for local repositories.

GitRAM does **not** store any passwords, OAuth tokens, or credentials; it delegates all authentication directly to GCM and the macOS Keychain.

---

## 🛠️ Installation & Setup

1. **Prerequisites**:
   * macOS 13 or newer.
   * Swift 6 / Xcode Command Line Tools.
   * Git Credential Manager (GCM) installed (e.g., via Homebrew: `brew install git-credential-manager`).

2. **Build**:
   Compile the release version of the binary:
   ```bash
   swift build -c release
   ```

3. **Install**:
   Copy the binary to a directory in your system `$PATH` (e.g., `/usr/local/bin`):
   ```bash
   cp .build/release/gitram /usr/local/bin/gitram
   ```

---

## 🚀 Usage

Navigate to any local Git repository directory and run:
```bash
gitram
```

### What GitRAM does:
1. Detects the local repository and its `origin` remote URL.
2. Lists the GitHub accounts stored in Git Credential Manager.
3. Identifies the account currently associated with the repository.
4. Renders a menu allowing you to select another account.
5. If a new account is chosen:
   * Sets the local Git username configuration (`git config credential.username`).
   * Erases the previous repository-specific credential entry.
   * Triggers GCM authentication to sign in or retrieve credentials for the new account.

---

## 🔒 Background & Daemon Status

* **No Background Processes**: GitRAM is a one-shot CLI utility. It does **not** run in the background, has no background services, no daemons, and consumes zero system resources when not actively running.
* **No Credential Storage**: All tokens, keys, and credentials remain securely managed by GCM and the macOS Keychain.
