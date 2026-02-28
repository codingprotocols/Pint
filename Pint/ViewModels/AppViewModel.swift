//
//  AppViewModel.swift
//  Pint
//
//  Created by Ajeet Yadav on 22/02/26.
//

import Foundation
import OSLog
import SwiftUI

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

// MARK: - OperationRunner

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
            let outputBuffer = UnsafeMutableSendableBox("")
            var lastUpdate = Date.distantPast

            do {
                try await action { text in
                    outputBuffer.value += text
                    // Throttle UI updates to ~10 Hz to avoid flooding the Main Actor.
                    let now = Date()
                    if now.timeIntervalSince(lastUpdate) > 0.1 {
                        let chunk = outputBuffer.value
                        Task { @MainActor in
                            capturedSelf.activeOperation?.output += chunk
                            if let out = capturedSelf.activeOperation?.output,
                               out.count > OperationRunner.maxOutputSize {
                                capturedSelf.activeOperation?.output =
                                    "… (output trimmed)\n" + String(out.suffix(OperationRunner.maxOutputSize))
                            }
                        }
                        outputBuffer.value = ""
                        lastUpdate = now
                    }
                }

                // Final flush of any buffered output.
                let finalChunk = outputBuffer.value
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

    // MARK: - Data Loading

    func loadAll() {
        Task {
            guard ShellExecutor.isBrewInstalled() else {
                brewAvailable = false
                showError("Homebrew is not installed. Please install Homebrew from https://brew.sh and relaunch Pint.")
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
                    outdatedPackages = try await brewService.listOutdated()
                    backgroundError = nil // Clear on success
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
        } catch {
            showError(error.localizedDescription)
        }
    }

    func loadOutdated() async {
        isLoadingOutdated = true
        defer { isLoadingOutdated = false }
        do {
            outdatedPackages = try await brewService.listOutdated()
        } catch {
            showError(error.localizedDescription)
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

    func updateBrew() {
        runBrewOperation(command: "update", packageName: "Homebrew") { [weak self] onOutput in
            try await self?.brewService.update(onOutput: onOutput)
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

        let defaultOnComplete: @Sendable () async -> Void = { [weak self] in
            await self?.loadInstalled()
            await self?.loadOutdated()
        }

        runner.run(
            operation: BrewOperation(command: command, packageName: packageName),
            action: action,
            onComplete: onComplete ?? defaultOnComplete
        )
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
