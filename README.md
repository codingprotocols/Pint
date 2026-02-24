# 🍺 TapHouse

> A beautiful, native macOS app for managing Homebrew packages — built with SwiftUI.

Browse, search, install, upgrade, and uninstall formulae and casks without touching the terminal. TapHouse brings Homebrew into a modern, vibrant GUI with gradient cards, glassmorphism, and smooth animations.

---

## ✨ Features

### Core
- **📊 Dashboard** — gradient stat cards showing total packages, formulae, casks, and available upgrades at a glance
- **📦 Installed Packages** — browse, filter (All/Formulae/Casks), and search with hover-reveal actions
- **⬆️ Upgrades** — see outdated packages with version comparison, upgrade individually or all at once
- **🔍 Search** — fast package discovery powered by the Homebrew JSON API
- **🩺 Brew Doctor** — run diagnostics and view health warnings with color-coded sections
- **📝 Release Notes** — view GitHub release notes for any package directly in-app

### Menu Bar
- **🔔 Menu Bar Icon** — lives in your menu bar for quick access, shows upgrade count
- **🔄 Background Updates** — automatically checks for outdated packages on a configurable interval
- **⚙️ Settings** — toggle menu bar visibility, launch at login, and update check frequency
- **🪟 Background Mode** — closing the window hides to menu bar instead of quitting

### Backup & Restore
- **📤 Export** — save your installed packages as JSON or Brewfile
- **📥 Import** — restore packages from a backup file with selective install
- **🔄 Brewfile Compatible** — export is compatible with `brew bundle install`

### Polish
- **🎨 Rich UI** — gradient cards, glassmorphism, hover animations, and vibrant colors
- **📺 Live Output** — watch install/upgrade/uninstall progress with collapsible terminal output
- **❌ Cancel Operations** — cancel any running brew operation mid-flight
- **💾 Memory Optimized** — capped output buffers, operation history limits, and smart caching
- **🍺 Brew Not Found** — step-by-step Homebrew installation guide when not detected

---

## 📸 Screenshots

<!-- Add screenshots here after first build -->

---

## 📥 Installation

### Download (Recommended)
1. Go to [Releases](../../releases/latest)
2. Download `TapHouse.zip`
3. Unzip and drag `TapHouse.app` to `/Applications`

#### Troubleshooting "App cannot be opened"
If you see the error *"Apple could not verify “TapHouse.app” is free of malware"* or similar when trying to open the app, macOS Gatekeeper is blocking it because it is not notarized.

**To bypass this:**
1. Try to open the app normally (you'll get the error).
2. Click **OK** on the error message.
3. Open **System Settings** and go to **Privacy & Security**.
4. Scroll down to the "Security" section. You should see a message saying *"TapHouse.app" was blocked from use because it is not from an identified developer*.
5. Click the **Open Anyway** button next to it.
6. Enter your Mac password/Touch ID if prompted, and then click **Open**.

*(Alternatively, you can just **Right-click** or **Control-click** on `TapHouse.app` in Finder and select **Open**).*


### Build from Source
1. **Clone the repo**
   ```bash
   git clone https://github.com/codingprotocols/TapHouse.git
   cd TapHouse/TapHouse
   ```

2. **Open in Xcode**
   ```bash
   open TapHouse.xcodeproj
   ```

3. **Build & Run** — press `⌘R`

---

## 📋 Requirements

| Requirement | Version |
|---|---|
| macOS | 14.0 (Sonoma) or later |
| Xcode | 15.0+ (build from source) |
| Homebrew | Installed ([brew.sh](https://brew.sh)) |

> If Homebrew is not installed, TapHouse shows step-by-step installation instructions on launch.

---

## 🏗️ Project Structure

```
TapHouse/
├── TapHouseApp.swift              # App entry point + MenuBarExtra + Settings
├── ContentView.swift              # Root NavigationSplitView + BrewNotFoundView
├── Models/
│   ├── BrewPackage.swift          # Data models (BrewPackage, ReleaseNote, etc.)
│   └── AppSettings.swift          # Settings keys and enums
├── ViewModels/
│   └── AppViewModel.swift         # Central @Observable view model
├── Views/
│   ├── SidebarView.swift          # Sidebar navigation with gradient icons
│   ├── DashboardView.swift        # Dashboard with gradient stat cards
│   ├── InstalledView.swift        # Installed packages with filter chips
│   ├── UpgradesView.swift         # Outdated packages with release notes
│   ├── SearchView.swift           # Package search
│   ├── BackupView.swift           # Export/Import packages
│   ├── DoctorView.swift           # brew doctor diagnostics
│   ├── PackageDetailView.swift    # Package detail with hero header
│   ├── MenuBarView.swift          # Menu bar popover
│   ├── SettingsView.swift         # App settings
│   └── TerminalOutputView.swift   # Live operation output banner
└── Services/
    ├── ShellExecutor.swift        # Low-level Process wrapper
    ├── BrewService.swift          # High-level brew operations
    ├── BrewAPIClient.swift        # Homebrew JSON API + GitHub releases
    └── BackupManager.swift        # Export/Import logic
```

---

## 🧱 Architecture

| Layer | Technology |
|---|---|
| UI | SwiftUI, NavigationSplitView, MenuBarExtra |
| State | @Observable, @MainActor |
| Networking | URLSession (Homebrew JSON API, GitHub Releases) |
| Shell | Foundation.Process |
| Concurrency | Swift Concurrency (async/await, actors) |
| Settings | @AppStorage, SMAppService |

---

## 🚀 Releasing

TapHouse uses GitHub Actions to automatically build and create a release when you push a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This triggers the CI workflow which:
1. Builds the app on macOS
2. Creates a `.zip` archive
3. Publishes a GitHub Release with the archive attached

---

## 📄 License

MIT © [Ajeet Yadav](https://github.com/codingprotocols)
