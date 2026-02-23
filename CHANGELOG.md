# Changelog

All notable changes to TapHouse will be documented in this file.

## [1.0.0] — 2026-02-23

### 🎉 Initial Release

**TapHouse** — a native macOS GUI for managing Homebrew packages, built with SwiftUI.

### Features
- **Dashboard** — overview of installed formulae, casks, and outdated packages
- **Installed Packages** — browse, filter, and uninstall packages with hover actions
- **Upgrades** — view outdated packages; upgrade individually or all at once
- **Search** — fast package search powered by the Homebrew JSON API
- **Brew Doctor** — run diagnostics and view health warnings in-app
- **Inline Operation Output** — install/upgrade/uninstall progress shown inline with collapsible terminal output
- **Cancel Operations** — cancel any running brew operation mid-flight
- **Homebrew Detection** — step-by-step installation guide when Homebrew is not found
- **Smart PATH Handling** — ensures `/opt/homebrew/bin` and `/opt/homebrew/sbin` are correctly prioritised, matching the user's shell environment

### Architecture
- SwiftUI with `@Observable` and `NavigationSplitView`
- Actor-based concurrency (`ShellExecutor`, `BrewAPIClient`)
- Dual data source: CLI for mutations, JSON API for search
- Streaming output via `Foundation.Process` pipes
- Task-based cancellation bridged to process termination
