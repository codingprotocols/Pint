# Changelog

All notable changes to TapHouse will be documented in this file.

## [1.1.0] — 2026-02-23

### ✨ New Features
- **Menu Bar Integration** — TapHouse lives in your menu bar with a dynamic icon showing update availability
- **Background Update Checking** — automatically checks for outdated packages on a configurable interval (15m / 1h / 4h / daily)
- **Settings Window** — toggle menu bar visibility, launch at login, and update check frequency
- **Background Mode** — closing the main window hides to menu bar instead of quitting the app
- **Package Release Notes** — view GitHub release notes directly in package details and upgrade views
- **Backup & Restore** — export installed packages as JSON or Brewfile, import and selectively reinstall
- **Brewfile Support** — export is fully compatible with `brew bundle install`

### 🎨 UI Redesign
- Rich/vibrant design with gradient stat cards, glassmorphism sections, and hover animations
- Gradient icon badges in sidebar with vibrant color scheme per section
- Filter chips for installed packages (All / Formulae / Casks)
- Hover-reveal action buttons (upgrade, uninstall) on package rows
- Polished empty states with gradient circles and icons
- Gradient border strokes on doctor diagnostic cards
- Hero header with gradient icon on package detail view
- Glassmorphism release notes section with expand/collapse

### ⚡ Performance
- Capped streaming output buffer at 50KB to prevent unbounded memory growth
- Trimmed archived operation output to 500 characters
- Capped operation history at 20 entries
- Added in-memory cache for GitHub release notes (10-min TTL)
- Added memory pressure observer to auto-clear all caches when macOS signals low memory

### 🐛 Fixes
- Fixed "Open TapHouse" from menu bar not working on first click after window close
- Fixed ShapeStyle type mismatches in hover ternary expressions

---

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
- **Smart PATH Handling** — ensures `/opt/homebrew/bin` and `/opt/homebrew/sbin` are correctly prioritised

### Architecture
- SwiftUI with `@Observable` and `NavigationSplitView`
- Actor-based concurrency (`ShellExecutor`, `BrewAPIClient`)
- Dual data source: CLI for mutations, JSON API for search
- Streaming output via `Foundation.Process` pipes
- Task-based cancellation bridged to process termination
