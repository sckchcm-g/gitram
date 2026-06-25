# GitRAM

Git Repository Account Manager (GitRAM) is a lightweight terminal wrapper around Git for macOS. It simplifies switching between multiple GitHub accounts for local repositories and securely manages credentials.

GitRAM stores your GitHub Personal Access Tokens (PATs) securely in the macOS Keychain under the service name `gitram`.

---

## 🛠️ Installation & Setup

1. **Prerequisites**:
   * macOS 13 or newer.
   * Swift 6 / Xcode Command Line Tools.
   * Git Credential Manager (GCM) (optional, for migration/cache cleanup).

2. **Build**:
   Compile the release version of the binary:
   ```bash
   swift build -c release
   ```

3. **Install**:
   Copy the binary to `/usr/local/bin`:
   ```bash
   sudo cp .build/release/gitram /usr/local/bin/gitram
   ```

4. **Configure Git**:
   Register GitRAM as your global credential helper:
   ```bash
   git config --global credential.helper /usr/local/bin/gitram
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

## 🔒 Background & Security

* **No Background Processes**: GitRAM is a one-shot CLI utility. It does **not** run in the background, has no background services, no daemons, and consumes zero system resources when not actively running.
* **Secure Credential Storage**: All Personal Access Tokens are stored securely in the native macOS Keychain under the `gitram` service and are accessed only when Git requests credentials.
