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

## 🚀 Commands Reference & Usage

### 1. Switch Account (Default)
Navigate to any local Git repository and run `gitram` to switch its active GitHub account:
```bash
gitram
```
*It detects the local repository and displays a menu to select from your authenticated accounts. When selected, it configures `credential.username` locally for that repository.*

### 2. Add a New User/Account
To authenticate and add a new GitHub account to GitRAM:
```bash
gitram add
# Or add a specific username:
gitram add <username>
```
*You will be prompted to choose between **Browser login** (OAuth device flow, requires one-time `gitram setup`) and **Personal Access Token** (generate a PAT at github.com/settings/tokens with `repo` and `read:org` scopes, and paste it).*

### 3. List Registered Accounts
To list all GitHub accounts registered with GitRAM and check their authentication status:
```bash
gitram accounts
```

### 4. Show Status
To check the current repository information and its active GitHub account details:
```bash
gitram status
```

### 5. Remove a User/Account
To remove a GitHub account and securely delete its token from the macOS Keychain:
```bash
gitram remove
# Or remove a specific username:
gitram remove <username>
```

### 6. Run Diagnostics
To troubleshoot setup issues and check if your credential helper and keychain configuration are healthy:
```bash
gitram doctor
```

### 7. Setup OAuth App (Optional)
If you want to use the browser-based login instead of manual PAT input, configure your own GitHub OAuth App client ID:
```bash
gitram setup
```

---

## 🔒 Background & Security

* **No Background Processes**: GitRAM is a one-shot CLI utility. It does **not** run in the background, has no background services, no daemons, and consumes zero system resources when not actively running.
* **Secure Credential Storage**: All Personal Access Tokens are stored securely in the native macOS Keychain under the `gitram` service and are accessed only when Git requests credentials.
