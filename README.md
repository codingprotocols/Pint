# 🍺 TapHouse

A native macOS app for managing Homebrew packages — built with **SwiftUI**.

Browse, search, install, upgrade, and uninstall formulae and casks without touching the terminal.

---

## Features

- **Dashboard** — overview of installed formulae, casks, and outdated packages at a glance
- **Installed Packages** — browse and filter everything Homebrew has installed
- **Upgrades** — see outdated packages and upgrade them individually or all at once
- **Search** — find new formulae and casks via the Homebrew JSON API (fast, no CLI overhead)
- **Brew Doctor** — run diagnostics and view health warnings inside the app
- **Live Terminal Output** — watch install/upgrade/uninstall progress in real time
- **Package Details** — view version, description, homepage, and type for any package

## Screenshots

<!-- Add screenshots here -->

## Requirements

| Requirement | Version |
|---|---|
| macOS | 14.0 (Sonoma) or later |
| Xcode | 15.0+ |
| Homebrew | Installed ([brew.sh](https://brew.sh)) |

> If Homebrew is not installed, TapHouse shows step-by-step installation instructions on launch.

## Getting Started

1. **Clone the repo**
   ```bash
   git clone https://github.com/yourusername/TapHouse.git
   cd TapHouse/TapHouse
   ```

2. **Open in Xcode**
   ```bash
   open TapHouse.xcodeproj
   ```

3. **Build & Run** — press `⌘R`

> **Note:** The App Sandbox entitlement is disabled so TapHouse can execute `/opt/homebrew/bin/brew` directly.

## Project Structure

```
TapHouse/
├── TapHouseApp.swift          # App entry point
├── ContentView.swift          # Root NavigationSplitView + BrewNotFoundView
├── Models/
│   └── BrewPackage.swift      # BrewPackage, PackageType, BrewStatus, BrewOperation
├── ViewModels/
│   └── AppViewModel.swift     # Central @Observable view model
├── Views/
│   ├── SidebarView.swift      # Sidebar navigation
│   ├── DashboardView.swift    # Home dashboard
│   ├── InstalledView.swift    # Installed packages list
│   ├── UpgradesView.swift     # Outdated packages
│   ├── SearchView.swift       # Package search
│   ├── DoctorView.swift       # brew doctor output
│   ├── PackageDetailView.swift# Package detail sheet
│   └── TerminalOutputView.swift# Live operation output
└── Services/
    ├── ShellExecutor.swift    # Low-level Process wrapper for brew CLI
    ├── BrewService.swift      # High-level brew operations (install, upgrade, etc.)
    └── BrewAPIClient.swift    # Homebrew JSON API client (search & info)
```

## Architecture

- **SwiftUI + @Observable** — reactive UI powered by the Observation framework
- **Actor-based concurrency** — `ShellExecutor` and `BrewAPIClient` are Swift actors for safe concurrent access
- **Dual data source** — CLI (`BrewService`) for mutations, JSON API (`BrewAPIClient`) for fast search & package info
- **Streaming output** — pipe-based real-time terminal output during long operations

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI, NavigationSplitView |
| State | @Observable, @MainActor |
| Networking | URLSession (Homebrew JSON API) |
| Shell | Foundation.Process |
| Concurrency | Swift Concurrency (async/await, actors) |

## License

MIT © [Ajeet Yadav](https://github.com/yourusername)
