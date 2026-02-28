# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Pint is a native macOS SwiftUI app (macOS 14.0+) for managing Homebrew packages via a GUI. It wraps `brew` CLI operations in a modern interface with live streaming output, cancellable operations, and a menu bar popover.

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

`OperationRunner` (defined at the bottom of `AppViewModel.swift`) owns the brew operation lifecycle: output buffering, history (capped at 20), task cancellation, and UserDefaults persistence. `AppViewModel` holds `let runner: OperationRunner` and exposes forwarding properties (`isOperationRunning`, `activeOperation`, `operationHistory`) so existing views need no changes. The forwarding properties work reactively because `@Observable` cascades through nested `@Observable` objects.

### Dependency Injection

All service calls go through protocols to enable testing without a real Homebrew installation:
- `BrewServiceProtocol` — defined in `BrewService.swift`; `BrewService` is the default implementation
- `BrewAPIClientProtocol` — defined in `BrewAPIClient.swift`; `BrewAPIClient` (actor) is the default

Both `AppViewModel` and `ServicesViewModel` accept `(any BrewServiceProtocol)? = nil` in their `init`; passing `nil` uses the real implementation. Tests inject mocks. `BrewService` similarly accepts `(any BrewAPIClientProtocol)? = nil`.

The project uses `-default-isolation=MainActor`, so all types are `@MainActor` by default. Actor default parameter values (e.g., `OperationRunner()`) must be initialised inside `init` bodies — not as inline default expressions — to avoid "nonisolated context" errors.

### Shell Execution (`Services/ShellExecutor.swift`)

`ShellExecutor` is a `static`-method-only `actor` with two execution modes:
- `run(_:)` — collects full output then returns (used for non-interactive queries)
- `runStreaming(_:onOutput:)` — streams output chunks via callback with Swift Task cancellation bridged to `SIGTERM`

All brew processes inject `HOMEBREW_NO_AUTO_UPDATE=1` and a custom `PATH` that prepends `/opt/homebrew/bin` and `/usr/local/bin` to handle both Apple Silicon and Intel installs. Brew is expected at `/opt/homebrew/bin/brew` or `/usr/local/bin/brew`.

### Homebrew Operations (`Services/BrewService.swift`)

High-level brew CLI calls (list, install, uninstall, upgrade, outdated, info, taps, services, etc.). Uses `ShellExecutor.run` for JSON-returning commands and `ShellExecutor.runStreaming` for long-running operations (install/upgrade/uninstall) that emit live output to `AppViewModel.terminalOutput`.

### API Client (`Services/BrewAPIClient.swift`)

`BrewAPIClient` is a `@globalActor`-isolated singleton. It fetches from `formulae.brew.sh` for search and GitHub Releases API for release notes. Caches responses for 10 minutes; auto-clears caches on memory pressure notifications.

### Key Design Constraints

- **Output buffer cap**: Terminal output is capped at 50KB to prevent memory bloat on long operations.
- **Operation history**: Capped at 20 entries in `AppViewModel`.
- **Concurrency safety**: Use `@MainActor` for all UI state mutations. `ShellExecutor` and `BrewAPIClient` are actors to protect mutable state accessed from background tasks.
- **Task cancellation**: Running brew operations are stored as `Task` references in `AppViewModel` and cancelled via `.cancel()`, which propagates to `Process.terminate()` in `ShellExecutor`.
- **UI lockout during operations**: The `isOperationRunning` flag on `AppViewModel` disables relevant UI elements to prevent concurrent brew invocations.
