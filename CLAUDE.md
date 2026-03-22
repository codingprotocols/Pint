# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Pint is a native macOS SwiftUI app (macOS 26.2+) for managing Homebrew packages via a GUI. It wraps `brew` CLI operations in a modern interface with live streaming output, cancellable operations, and a menu bar popover.

## Build Commands

```bash
# Open in Xcode and press ⌘R
open Pint.xcodeproj

# Command-line build (Debug, active arch only)
xcodebuild -project Pint.xcodeproj -scheme Pint -configuration Debug build

# Release build (universal binary, no code signing)
xcodebuild -project Pint.xcodeproj \
  -scheme Pint \
  -configuration Release \
  -arch arm64 -arch x86_64 \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=NO build
```

There are no automated tests. Verification is manual via running the app.

## Version Management & Releasing

```bash
./bump-version.sh patch    # x.x.N
./bump-version.sh minor    # x.N.0
./bump-version.sh major    # N.0.0
./bump-version.sh build    # increment build number only

# Trigger a release (GitHub Actions builds and publishes automatically)
git tag v1.x.x && git push origin v1.x.x
```

The script edits `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` directly in `Pint.xcodeproj/project.pbxproj`.

## Architecture

The app follows a layered architecture: **Views → ViewModels → Services → Shell/API**.

### State Management

`AppViewModel` (`ViewModels/AppViewModel.swift`) is the central `@Observable @MainActor` class. It holds all package/tap state and drives every view via the SwiftUI environment (`PintApp.swift`).

`OperationRunner` (defined near the top of `AppViewModel.swift`, before `AppViewModel`) owns the brew operation lifecycle: output buffering, history (capped at 20), task cancellation, and UserDefaults persistence. `AppViewModel` holds `let runner: OperationRunner` and exposes forwarding properties (`isOperationRunning`, `activeOperation`, `operationHistory`). The forwarding properties work reactively because `@Observable` cascades through nested `@Observable` objects.

`OutputThrottler` is a private file-scope `@unchecked Sendable` class defined just above `OperationRunner`. It holds `nonisolated(unsafe) var buffer` and `nonisolated(unsafe) var lastUpdate` — the mutable state for the 10 Hz output throttle inside `OperationRunner.run`. It must be at file scope (not nested inside `OperationRunner`) so that `-default-isolation=MainActor` does not apply to its properties.

### Dependency Injection

All service calls go through protocols to enable testing without a real Homebrew installation:
- `BrewServiceProtocol` — defined in `BrewService.swift`; `BrewService` is the default implementation
- `BrewAPIClientProtocol` — defined in `BrewAPIClient.swift`; `BrewAPIClient` (actor) is the default

Both `AppViewModel` and `ServicesViewModel` accept `(any BrewServiceProtocol)? = nil` in their `init`; passing `nil` uses the real implementation. `BrewService` similarly accepts `(any BrewAPIClientProtocol)? = nil`.

### Shell Execution (`Services/ShellExecutor.swift`)

`ShellExecutor` is a `static`-method-only `actor` with two execution modes:
- `run(_:)` — collects full output then returns (used for non-interactive queries)
- `runStreaming(_:onOutput:)` — streams output chunks via callback with Swift Task cancellation bridged to `SIGTERM`

All brew processes inject `HOMEBREW_NO_AUTO_UPDATE=1` and a custom `PATH` that prepends `/opt/homebrew/bin` and `/usr/local/bin` to handle both Apple Silicon and Intel installs.

`UnsafeMutableSendableBox<T>` (defined at the top of `ShellExecutor.swift`) is used for pipe data collection. All its members that touch `_value` are marked `nonisolated` or `nonisolated(unsafe)` so `readabilityHandler` callbacks (called off-MainActor) can access them despite the project-wide `-default-isolation=MainActor`.

**Brew launch failure handling**: Both `run(_:)` and `runStreaming(_:onOutput:)` wrap `process.run()` in a `do/catch` that converts **any** launch failure (file not found, permission denied, sandbox block) into `ShellError.brewNotFound`. This prevents macOS/Foundation-level error strings (e.g. "The file 'brew' doesn't exist.") from surfacing in the UI.

### Homebrew Operations (`Services/BrewService.swift`)

High-level brew CLI calls (list, install, uninstall, upgrade, outdated, info, pin, unpin, autoremove, taps, services, etc.). Uses `ShellExecutor.run` for JSON-returning commands and `ShellExecutor.runStreaming` for long-running operations that emit live output.

### API Client (`Services/BrewAPIClient.swift`)

`BrewAPIClient` is a `@globalActor`-isolated singleton. Fetches from `formulae.brew.sh` for search and the GitHub Releases API for release notes (no auth token — unauthenticated, 60 req/hr limit). On 403/429, returns `nil` without caching so the next call retries. Caches list responses for 10 minutes, release notes for 1 hour; auto-clears on memory pressure.

### Views

- **`DashboardView`** — stat cards, outdated package list, recent operations, Update/Autoremove/Cleanup/Upgrade All actions.
- **`InstalledView`** — sortable/filterable package list with inline split panel. Clicking a row opens `PackageDetailView` on the right (300 pt list + flexible detail pane). Selection is driven by `@State private var selectedPackage: BrewPackage?`; the detail always reads live state via `liveSelected`. Uses `.id(pkg.name)` on `PackageDetailView` to force a fresh view (and fresh `.task`) on each selection change.
- **`PackageDetailView`** — per-package detail: hero header, info cards, pin/unpin (formulae only), upgrade/uninstall actions, caveats, release notes from GitHub, personal notes editor, dependency tree sheet.
- **`UpgradesView`** — lists outdated packages; distinguishes pinned formulae (shown with "Won't upgrade" label, excluded from Upgrade All count via `upgradablePackages`).
- **`SearchView`** — live search with debounce (300 ms), popular suggestions when query is empty, multi-select bulk install mode.
- **`ContentView`** — on startup shows a spinner while brew availability is being checked (`isCheckingBrew = true`), then either shows `BrewNotFoundView` or the normal UI. `BrewNotFoundView` detects `.notInstalled` vs `.pathNotConfigured(brewPath:)` via `BrewNotFoundReason` and shows tailored instructions including the `shellenv` setup step.
- **`Helpers/LiquidGlassModifier.swift`** — `ViewModifier` + `.liquidGlass(...)` extension that applies a frosted-glass look (material background, rounded clip, white border stroke, drop shadow). Used across sidebar, installed list, and dashboard for visual consistency.

### Key Design Constraints

- **`-default-isolation=MainActor`**: All types in the project inherit `@MainActor` isolation unless explicitly annotated otherwise. Consequences:
  - Stored properties accessed from `@Sendable` closures or `readabilityHandler` callbacks must be `nonisolated(unsafe) var`.
  - `nonisolated` methods/computed properties can access `nonisolated(unsafe)` stored properties freely.
  - Use `[self]` (strong capture) instead of `[weak self]` in `@Sendable` closures — `[weak self]` creates a captured `var` (Optional) which Swift 6 forbids in `@Sendable` closures. Strong capture is safe because `AppViewModel` is `@MainActor` (hence `Sendable`) and tasks complete before any potential deallocation.
  - Actor default parameter values (e.g., `OperationRunner()`) must be initialised inside `init` bodies, not as inline default expressions.
- **Output buffer cap**: Terminal output is capped at 50 KB to prevent memory bloat on long operations.
- **Operation history**: Capped at 20 entries.
- **Task cancellation**: Running brew operations are stored as `Task` references in `OperationRunner` and cancelled via `.cancel()`, which propagates to `Process.terminate()` in `ShellExecutor`.
- **UI lockout during operations**: `isOperationRunning` disables relevant UI elements to prevent concurrent brew invocations.
- **Release notes**: GitHub API is unauthenticated. Rate-limit responses (403/429) return `nil` and are not cached. No GitHub token support.
- **Brew availability check**: `AppViewModel` initialises `brewAvailable = false` and `isCheckingBrew = true`. `loadAll()` calls `ShellExecutor.discoverBrewPath()` which checks standard paths (`/opt/homebrew/bin/brew`, `/usr/local/bin/brew`, Linux prefix) then falls back to asking each available login shell (`zsh`, `bash`, `sh`) via `which brew`. The discovered path is cached so subsequent `resolveBrewPath()` calls (used by every brew command) are instant and work regardless of where the user installed brew. `loadInstalled()` and `loadOutdated()` also catch `ShellError.brewNotFound` defensively and set `brewAvailable = false` rather than showing an alert.

---

## Code Review Workflow

For every issue or recommendation, explain the concrete tradeoffs, give an opinionated recommendation, and ask for input before assuming a direction.

**Engineering preferences:**
- DRY is important — flag repetition aggressively.
- Well-tested code is non-negotiable; err toward more tests than fewer.
- "Engineered enough" — not fragile/hacky, not prematurely abstracted.
- Handle more edge cases, not fewer; thoughtfulness over speed.
- Bias toward explicit over clever.

**Review sections:**

1. **Architecture** — system design, component boundaries, dependency graph, data flow, security.
2. **Code quality** — organization, DRY violations, error handling gaps, technical debt, over/under engineering.
3. **Tests** — coverage gaps, assertion strength, missing edge cases, untested failure modes.
4. **Performance** — memory usage, caching opportunities, slow or high-complexity paths.

**For each issue found:** describe the problem with file + line reference, present 2–3 options (including "do nothing"), specify effort/risk/impact/maintenance for each, give a recommended option mapped to the preferences above, then ask before proceeding.

**Before starting a review, ask:**
- **BIG CHANGE**: interactive, one section at a time, at most 4 top issues per section.
- **SMALL CHANGE**: interactive, one question per section.

**For each stage:** output explanation + pros/cons + opinionated recommendation, then use `AskUserQuestion`. Number issues, letter options (e.g. Issue 1 Option A). Recommended option is always listed first.