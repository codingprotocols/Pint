//
//  AppViewModel.swift
//  Pint
//
//  Created by Ajeet Yadav on 22/02/26.
//

import Foundation
import OSLog
import SwiftUI
import UserNotifications

private let logger = Logger(subsystem: "com.pint", category: "app-vm")

// MARK: - Navigation

/// Navigation destinations for the sidebar.
enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case installed = "Installed"
    case services = "Services"
    case taps = "Taps"
    case quarantine = "Quarantine"
    case history = "History"
    case upgrades = "Upgrades"
    case search = "Search"
    case backup = "Backup"
    case doctor = "Brew Doctor"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .installed: return "shippingbox.fill"
        case .services: return "square.stack.3d.up.fill"
        case .taps: return "spigot.fill"
        case .quarantine: return "shield.slash.fill"
        case .history: return "clock.arrow.circlepath"
        case .upgrades: return "arrow.up.circle.fill"
        case .search: return "magnifyingglass"
        case .backup: return "icloud.fill"
        case .doctor: return "stethoscope"
        }
    }
}

// MARK: - Brew Not Found Reason

/// Why Homebrew could not be located at a known path.
enum BrewNotFoundReason: Equatable {
    /// No brew binary found anywhere — Homebrew is not installed.
    case notInstalled
    /// Brew was found via the user's shell PATH but not at the standard locations
    /// Pint checks (`/opt/homebrew/bin/brew` or `/usr/local/bin/brew`).
    case pathNotConfigured(brewPath: String)
}

// MARK: - OperationRunner

/// Mutable state used only within OperationRunner's output callback.
/// Defined at file scope so it has no actor isolation. Access is serial
/// (single unstructured Task, single streaming callback), making @unchecked Sendable safe.
private final class OutputThrottler: @unchecked Sendable {
    nonisolated(unsafe) var buffer = ""
    nonisolated(unsafe) var lastUpdate = Date.distantPast
}

/// Owns the full lifecycle of a single brew operation: output buffering, history, cancellation.
/// Extracted from AppViewModel to give it a focused responsibility and enable independent testing.
@Observable
@MainActor
final class OperationRunner {

    var activeOperation: BrewOperation? = nil
    var operationHistory: [BrewOperation] = []

    var isOperationRunning: Bool {
        activeOperation != nil && !(activeOperation?.isComplete ?? false)
    }

    private var runningTask: Task<Void, Never>?
    private static let maxOutputSize = 50_000

    // MARK: - Run

    /// Start a brew operation. Silently no-ops if one is already running — callers should
    /// check `isOperationRunning` and surface an appropriate message to the user first.
    func run(
        operation: BrewOperation,
        action: @escaping @Sendable (@escaping @Sendable (String) -> Void) async throws -> Void,
        onComplete: (@Sendable () async -> Void)? = nil
    ) {
        guard !isOperationRunning else { return }

        activeOperation = operation
        let capturedSelf = self

        runningTask = Task {
            let throttler = OutputThrottler()

            do {
                try await action { text in
                    throttler.buffer += text
                    // Throttle UI updates to ~10 Hz to avoid flooding the Main Actor.
                    let now = Date()
                    if now.timeIntervalSince(throttler.lastUpdate) > 0.1 {
                        let chunk = throttler.buffer
                        Task { @MainActor in
                            capturedSelf.activeOperation?.output += chunk
                            if let out = capturedSelf.activeOperation?.output,
                               out.count > OperationRunner.maxOutputSize {
                                capturedSelf.activeOperation?.output =
                                    "… (output trimmed)\n" + String(out.suffix(OperationRunner.maxOutputSize))
                            }
                        }
                        throttler.buffer = ""
                        throttler.lastUpdate = now
                    }
                }

                // Final flush of any buffered output.
                let finalChunk = throttler.buffer
                await MainActor.run {
                    if !finalChunk.isEmpty { capturedSelf.activeOperation?.output += finalChunk }
                    capturedSelf.activeOperation?.isComplete = true
                    capturedSelf.activeOperation?.isSuccess = true
                }

            } catch is CancellationError {
                await MainActor.run {
                    capturedSelf.activeOperation?.isComplete = true
                    capturedSelf.activeOperation?.isSuccess = false
                    capturedSelf.activeOperation?.output += "\n⚠️ Cancelled by user."
                }
            } catch let error as ShellError where error == .cancelled {
                await MainActor.run {
                    capturedSelf.activeOperation?.isComplete = true
                    capturedSelf.activeOperation?.isSuccess = false
                    capturedSelf.activeOperation?.output += "\n⚠️ Cancelled by user."
                }
            } catch {
                await MainActor.run {
                    capturedSelf.activeOperation?.isComplete = true
                    capturedSelf.activeOperation?.isSuccess = false
                    capturedSelf.activeOperation?.output += "\n❌ Error: \(error.localizedDescription)"
                }
            }

            // Archive to history (trimmed to save memory) and persist.
            await MainActor.run {
                if var op = capturedSelf.activeOperation {
                    if op.output.count > 500 {
                        op.output = String(op.output.suffix(500))
                    }
                    capturedSelf.operationHistory.insert(op, at: 0)
                    if capturedSelf.operationHistory.count > 20 {
                        capturedSelf.operationHistory = Array(capturedSelf.operationHistory.prefix(20))
                    }
                    capturedSelf.saveHistory()
                }
                capturedSelf.runningTask = nil
            }

            await onComplete?()
        }
    }

    func cancel() {
        runningTask?.cancel()
        runningTask = nil
    }

    func dismiss() {
        activeOperation = nil
        saveHistory()
    }

    func clearHistory() {
        operationHistory.removeAll()
        saveHistory()
    }

    // MARK: - Persistence

    func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: AppSettingsKeys.operationHistory),
           let decoded = try? JSONDecoder().decode([BrewOperation].self, from: data) {
            operationHistory = decoded
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(operationHistory) {
            UserDefaults.standard.set(data, forKey: AppSettingsKeys.operationHistory)
        }
    }
}

// MARK: - AppViewModel

/// Main ViewModel for the entire application.
@MainActor
@Observable
final class AppViewModel {

    // MARK: - Sub-objects

    let runner: OperationRunner

    // MARK: - State

    var selectedNav: NavigationItem = .dashboard
    var installedPackages: [BrewPackage] = []
    var outdatedPackages: [BrewPackage] = []
    var searchResults: [BrewPackage] = []
    var searchQuery: String = ""
    var doctorOutput: String = ""
    var brewVersion: String = ""
    var diskUsage: String = ""
    var taps: [String] = []

    var brewAvailable: Bool = true
    var brewNotFoundReason: BrewNotFoundReason = .notInstalled
    var isLoadingInstalled: Bool = false
    var isLoadingOutdated: Bool = false
    var isSearching: Bool = false
    var isLoadingDoctor: Bool = false
    var isLoadingDiskUsage: Bool = false
    var isRefreshing: Bool = false
    var isLoadingTaps: Bool = false

    // Background error — shown as a non-intrusive banner (not a blocking alert).
    var backgroundError: String? = nil

    // Error handling (foreground, blocking alert)
    var errorMessage: String? = nil
    var showError: Bool = false

    // Notifications & update tracking
    var lastOutdatedCheck: Date? = nil
    /// Reactive date of last `brew update` — initialised from UserDefaults, written back on update.
    var lastBrewUpdateDate: Date? = {
        let ts = UserDefaults.standard.double(forKey: AppSettingsKeys.lastBrewUpdate)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }()
    var isBrewUpdateStale: Bool {
        guard let date = lastBrewUpdateDate else { return true }
        return Date().timeIntervalSince(date) > 86400
    }
    /// Read directly from UserDefaults — no reactivity needed (only checked when sending notifications).
    private var notificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: AppSettingsKeys.notificationsEnabled) as? Bool ?? true
    }

    // Filters
    var installedFilter: PackageType? = nil
    var installedSearchText: String = ""

    // Metadata persistence
    private var metadata: [String: PackageMetadata] = [:]

    // Background periodic update check task.
    private var backgroundCheckTask: Task<Void, Never>?

    // MARK: - Service

    private let brewService: any BrewServiceProtocol

    // MARK: - Init

    /// Pass concrete implementations in tests; leave nil for production defaults.
    init(
        brewService: (any BrewServiceProtocol)? = nil,
        runner: OperationRunner? = nil
    ) {
        self.brewService = brewService ?? BrewService()
        self.runner = runner ?? OperationRunner()
    }

    // MARK: - Forwarding Properties (backward-compatible proxies for views)

    var activeOperation: BrewOperation? { runner.activeOperation }
    var operationHistory: [BrewOperation] { runner.operationHistory }

    /// Whether a blocking Homebrew operation is currently running.
    var isOperationRunning: Bool { runner.isOperationRunning }

    func cancelOperation() { runner.cancel() }
    func dismissOperation() { runner.dismiss() }
    func clearHistory() { runner.clearHistory() }

    /// Refresh the data for whichever tab is currently visible (bound to ⌘R).
    func refreshCurrentView() {
        switch selectedNav {
        case .dashboard:
            Task { await loadInstalled(); await loadOutdated() }
        case .installed:
            Task { await loadInstalled() }
        case .upgrades:
            Task { await loadOutdated() }
        case .taps:
            Task { await loadTaps() }
        case .search:
            Task { await performSearch() }
        case .doctor:
            Task { await loadDoctor() }
        default:
            break
        }
    }

    // MARK: - Computed

    var filteredInstalled: [BrewPackage] {
        var list = installedPackages
        if let filter = installedFilter {
            list = list.filter { $0.type == filter }
        }
        if !installedSearchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(installedSearchText) }
        }
        return list
    }

    var hasUpdates: Bool { !outdatedPackages.isEmpty }
    var totalFormulae: Int { installedPackages.filter { $0.type == .formula }.count }
    var totalCasks: Int { installedPackages.filter { $0.type == .cask }.count }

    /// Outdated packages that brew will actually upgrade (pinned formulae are excluded).
    var upgradablePackages: [BrewPackage] {
        outdatedPackages.filter { pkg in
            guard pkg.type == .formula else { return true }
            return !(installedPackages.first { $0.name == pkg.name }?.isPinned ?? false)
        }
    }

    /// Number of outdated formulae that are pinned and will be skipped by `brew upgrade`.
    var pinnedOutdatedCount: Int { outdatedPackages.count - upgradablePackages.count }

    // MARK: - Data Loading

    func loadAll() {
        Task {
            guard ShellExecutor.isBrewInstalled() else {
                // Not at the standard paths — check if brew exists somewhere else via the shell.
                if let shellPath = ShellExecutor.findBrewViaShell() {
                    brewNotFoundReason = .pathNotConfigured(brewPath: shellPath)
                } else {
                    brewNotFoundReason = .notInstalled
                }
                brewAvailable = false
                return
            }
            brewAvailable = true
            isRefreshing = true
            defer { isRefreshing = false }

            loadMetadata()
            runner.loadHistory()
            await loadInstalled()
            await loadOutdated()
            await loadBrewVersion()
            await loadTaps()
            startBackgroundUpdateChecking()
        }
    }

    /// Periodically check for outdated packages in the background.
    /// Failures are surfaced as a non-intrusive banner rather than a blocking alert.
    func startBackgroundUpdateChecking() {
        backgroundCheckTask?.cancel()
        backgroundCheckTask = Task {
            while !Task.isCancelled {
                let interval = UserDefaults.standard.integer(forKey: AppSettingsKeys.updateCheckInterval)
                let seconds = interval > 0 ? interval : 3600
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { break }
                do {
                    let previousCount = outdatedPackages.count
                    outdatedPackages = try await brewService.listOutdated()
                    reconcileOutdatedStatus()
                    lastOutdatedCheck = Date()
                    backgroundError = nil
                    // Notify only when new packages become outdated since last check.
                    let newCount = outdatedPackages.count
                    if newCount > previousCount {
                        await sendUpdatesFoundNotification(count: newCount)
                    }
                } catch {
                    logger.error("Background update check failed: \(error)")
                    backgroundError = error.localizedDescription
                }
            }
        }
    }

    func loadInstalled() async {
        isLoadingInstalled = true
        defer { isLoadingInstalled = false }
        do {
            var packages = try await brewService.listInstalled()
            for i in 0..<packages.count {
                if let meta = metadata[packages[i].id] {
                    packages[i].isFavorite = meta.isFavorite
                    packages[i].notes = meta.notes
                }
            }
            installedPackages = packages
            reconcileOutdatedStatus()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func loadOutdated() async {
        isLoadingOutdated = true
        defer { isLoadingOutdated = false }
        do {
            outdatedPackages = try await brewService.listOutdated()
            reconcileOutdatedStatus()
            lastOutdatedCheck = Date()
        } catch {
            showError(error.localizedDescription)
        }
    }

    /// Syncs `isOutdated` on every `installedPackages` entry to match `outdatedPackages`.
    /// `brew outdated --json=v2` is the authoritative source; `brew info --installed` can
    /// diverge (e.g. for pinned formulae or greedy casks), causing false orange badges.
    private func reconcileOutdatedStatus() {
        guard !installedPackages.isEmpty else { return }
        let outdatedNames = Set(outdatedPackages.map { $0.name })
        for i in 0..<installedPackages.count {
            installedPackages[i].isOutdated = outdatedNames.contains(installedPackages[i].name)
        }
    }

    func loadBrewVersion() async {
        do {
            brewVersion = try await brewService.version()
        } catch { }
    }

    func loadTaps() async {
        isLoadingTaps = true
        defer { isLoadingTaps = false }
        do {
            taps = try await brewService.listTaps()
        } catch {
            logger.error("Failed to load taps: \(error)")
        }
    }

    func performSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await brewService.search(searchQuery)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func loadDoctor() async {
        isLoadingDoctor = true
        defer { isLoadingDoctor = false }
        do {
            doctorOutput = try await brewService.doctor()
        } catch {
            doctorOutput = "Error: \(error.localizedDescription)"
        }
    }

    func loadDiskUsage() async {
        do {
            diskUsage = try await brewService.getDiskUsage()
        } catch {
            diskUsage = "Error: \(error.localizedDescription)"
        }
    }

    func cleanupCache() {
        runBrewOperation(command: "cleanup", packageName: "Homebrew Cache") { [weak self] onOutput in
            try await self?.brewService.cleanupCache(onOutput: onOutput)
            await self?.loadDiskUsage()
        }
    }

    // MARK: - Package Operations

    func install(_ package: BrewPackage) {
        runBrewOperation(command: "install", package: package) { [weak self] onOutput in
            try await self?.brewService.install(package.name, isCask: package.type == .cask, onOutput: onOutput)
        }
    }

    func upgrade(_ package: BrewPackage) {
        runBrewOperation(command: "upgrade", package: package) { [weak self] onOutput in
            try await self?.brewService.upgrade(package.name, isCask: package.type == .cask, onOutput: onOutput)
        }
    }

    func uninstall(_ package: BrewPackage) {
        runBrewOperation(command: "uninstall", package: package) { [weak self] onOutput in
            try await self?.brewService.uninstall(package.name, isCask: package.type == .cask, onOutput: onOutput)
        }
    }

    func bulkUninstall(_ packages: [BrewPackage]) {
        runBrewOperation(command: "uninstall", packageName: "\(packages.count) packages") { [weak self] onOutput in
            for pkg in packages {
                onOutput("Uninstalling \(pkg.name)...\n")
                try await self?.brewService.uninstall(pkg.name, isCask: pkg.type == .cask, onOutput: onOutput)
            }
        }
    }

    func bulkUpgrade(_ packages: [BrewPackage]) {
        runBrewOperation(command: "upgrade", packageName: "\(packages.count) packages") { [weak self] onOutput in
            for pkg in packages {
                onOutput("Upgrading \(pkg.name)...\n")
                try await self?.brewService.upgrade(pkg.name, isCask: pkg.type == .cask, onOutput: onOutput)
            }
        }
    }

    func upgradeAll() {
        runBrewOperation(command: "upgrade --all", packageName: "All Packages") { [weak self] onOutput in
            try await self?.brewService.upgradeAll(onOutput: onOutput)
        }
    }

    /// Install multiple packages from search in one operation.
    /// Formulae and casks are batched separately; if both types are selected,
    /// casks are queued as a follow-up after formulae finish.
    func bulkInstallFromSearch(_ packages: [BrewPackage]) {
        let formulaeNames = packages.filter { $0.type == .formula }.map { $0.name }
        let caskNames     = packages.filter { $0.type == .cask    }.map { $0.name }

        if formulaeNames.isEmpty {
            // Casks only
            runBrewOperation(command: "install --cask", packageName: caskNames.joined(separator: " ")) { [weak self] onOutput in
                try await self?.brewService.installMultiple(caskNames, isCask: true, onOutput: onOutput)
            }
        } else if caskNames.isEmpty {
            // Formulae only
            runBrewOperation(command: "install", packageName: formulaeNames.joined(separator: " ")) { [weak self] onOutput in
                try await self?.brewService.installMultiple(formulaeNames, isCask: false, onOutput: onOutput)
            }
        } else {
            // Both types — install formulae first, then casks in onComplete
            runBrewOperation(command: "install", packageName: formulaeNames.joined(separator: " ")) { [weak self] onOutput in
                try await self?.brewService.installMultiple(formulaeNames, isCask: false, onOutput: onOutput)
            } onComplete: { [self] in
                await self.loadInstalled()
                await MainActor.run {
                    self.runBrewOperation(command: "install --cask", packageName: caskNames.joined(separator: " ")) { [self] onOutput in
                        try await self.brewService.installMultiple(caskNames, isCask: true, onOutput: onOutput)
                    }
                }
            }
        }
    }

    func autoRemove() {
        runBrewOperation(command: "autoremove", packageName: "orphaned dependencies") { [weak self] onOutput in
            try await self?.brewService.autoremove(onOutput: onOutput)
        } onComplete: { [weak self] in
            await self?.loadInstalled()
        }
    }

    func pin(_ package: BrewPackage) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await brewService.pin(package.name)
                if let idx = installedPackages.firstIndex(where: { $0.id == package.id }) {
                    installedPackages[idx].isPinned = true
                }
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func unpin(_ package: BrewPackage) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await brewService.unpin(package.name)
                if let idx = installedPackages.firstIndex(where: { $0.id == package.id }) {
                    installedPackages[idx].isPinned = false
                }
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func updateBrew() {
        runBrewOperation(command: "update", packageName: "Homebrew") { [weak self] onOutput in
            try await self?.brewService.update(onOutput: onOutput)
        } onComplete: { [self] in
            let now = Date()
            await MainActor.run {
                self.lastBrewUpdateDate = now
                UserDefaults.standard.set(now.timeIntervalSince1970, forKey: AppSettingsKeys.lastBrewUpdate)
            }
            await self.loadInstalled()
            await self.loadOutdated()
        }
    }

    // MARK: - Tap Operations

    func addTap(_ name: String) {
        runBrewOperation(command: "tap", packageName: name) { [weak self] onOutput in
            try await self?.brewService.addTap(name, onOutput: onOutput)
        } onComplete: { [weak self] in
            await self?.loadTaps()
        }
    }

    func removeTap(_ name: String) {
        runBrewOperation(command: "untap", packageName: name) { [weak self] onOutput in
            try await self?.brewService.removeTap(name, onOutput: onOutput)
        } onComplete: { [weak self] in
            await self?.loadTaps()
        }
    }

    // MARK: - Private Dispatch

    private func runBrewOperation(
        command: String,
        package: BrewPackage,
        action: @escaping @Sendable (@escaping @Sendable (String) -> Void) async throws -> Void,
        onComplete: (@Sendable () async -> Void)? = nil
    ) {
        runBrewOperation(command: command, packageName: package.name, action: action, onComplete: onComplete)
    }

    private func runBrewOperation(
        command: String,
        packageName: String,
        action: @escaping @Sendable (@escaping @Sendable (String) -> Void) async throws -> Void,
        onComplete: (@Sendable () async -> Void)? = nil
    ) {
        guard !runner.isOperationRunning else {
            showError("An operation is already in progress. Please wait for it to complete.")
            return
        }

        let defaultOnComplete: @Sendable () async -> Void = { [self] in
            await self.loadInstalled()
            await self.loadOutdated()
        }

        let baseComplete = onComplete ?? defaultOnComplete

        // Wrap completion to send a macOS notification after every operation.
        let wrappedComplete: @Sendable () async -> Void = { [self] in
            let isSuccess = await MainActor.run { self.runner.activeOperation?.isSuccess ?? true }
            await baseComplete()
            await self.sendOperationNotification(command: command, packageName: packageName, isSuccess: isSuccess)
        }

        runner.run(
            operation: BrewOperation(command: command, packageName: packageName),
            action: action,
            onComplete: wrappedComplete
        )
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendOperationNotification(command: String, packageName: String, isSuccess: Bool) async {
        guard notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = isSuccess ? "✓ Operation Completed" : "✗ Operation Failed"
        content.body = "brew \(command) \(packageName)"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func sendUpdatesFoundNotification(count: Int) async {
        guard notificationsEnabled, count > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Homebrew Updates Available"
        content.body = "\(count) package\(count == 1 ? "" : "s") ready to upgrade"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "pint-updates-found", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - Metadata Persistence

    private struct PackageMetadata: Codable {
        let isFavorite: Bool
        let notes: String
    }

    private func loadMetadata() {
        if let data = UserDefaults.standard.data(forKey: AppSettingsKeys.packageMetadata),
           let decoded = try? JSONDecoder().decode([String: PackageMetadata].self, from: data) {
            metadata = decoded
        }
    }

    private func saveMetadata() {
        if let data = try? JSONEncoder().encode(metadata) {
            UserDefaults.standard.set(data, forKey: AppSettingsKeys.packageMetadata)
        }
    }

    func toggleFavorite(_ package: BrewPackage) {
        var meta = metadata[package.id] ?? PackageMetadata(isFavorite: false, notes: "")
        meta = PackageMetadata(isFavorite: !meta.isFavorite, notes: meta.notes)
        metadata[package.id] = meta
        saveMetadata()

        if let index = installedPackages.firstIndex(where: { $0.id == package.id }) {
            installedPackages[index].isFavorite = meta.isFavorite
        }
        if let index = searchResults.firstIndex(where: { $0.id == package.id }) {
            searchResults[index].isFavorite = meta.isFavorite
        }
    }

    func updateNotes(_ package: BrewPackage, notes: String) {
        var meta = metadata[package.id] ?? PackageMetadata(isFavorite: false, notes: "")
        meta = PackageMetadata(isFavorite: meta.isFavorite, notes: notes)
        metadata[package.id] = meta
        saveMetadata()

        if let index = installedPackages.firstIndex(where: { $0.id == package.id }) {
            installedPackages[index].notes = meta.notes
        }
        if let index = searchResults.firstIndex(where: { $0.id == package.id }) {
            searchResults[index].notes = meta.notes
        }
    }
}
