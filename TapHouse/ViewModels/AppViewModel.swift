//
//  AppViewModel.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import Foundation
import SwiftUI

/// Navigation destinations for the sidebar.
enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case installed = "Installed"
    case upgrades = "Upgrades"
    case search = "Search"
    case backup = "Backup"
    case doctor = "Brew Doctor"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .installed: return "shippingbox.fill"
        case .upgrades: return "arrow.up.circle.fill"
        case .search: return "magnifyingglass"
        case .backup: return "icloud.fill"
        case .doctor: return "stethoscope"
        }
    }
}

/// Main ViewModel for the entire application.
@MainActor
@Observable
final class AppViewModel {

    // MARK: - State

    var selectedNav: NavigationItem = .dashboard
    var installedPackages: [BrewPackage] = []
    var outdatedPackages: [BrewPackage] = []
    var searchResults: [BrewPackage] = []
    var searchQuery: String = ""
    var doctorOutput: String = ""
    var brewVersion: String = ""

    var brewAvailable: Bool = true
    var isLoadingInstalled: Bool = false
    var isLoadingOutdated: Bool = false
    var isSearching: Bool = false
    var isLoadingDoctor: Bool = false

    // Operation tracking
    var activeOperation: BrewOperation? = nil
    var operationHistory: [BrewOperation] = []

    /// Max output buffer size (50 KB) to avoid unbounded memory growth.
    private static let maxOutputSize = 50_000

    /// The currently running Task — stored so it can be cancelled.
    private var runningTask: Task<Void, Never>?

    /// Background periodic update check task.
    private var backgroundCheckTask: Task<Void, Never>?

    /// Whether there are packages available for upgrade.
    var hasUpdates: Bool {
        !outdatedPackages.isEmpty
    }

    // Error handling
    var errorMessage: String? = nil
    var showError: Bool = false

    // Filters
    var installedFilter: PackageType? = nil
    var installedSearchText: String = ""

    // MARK: - Services

    private let brewService = BrewService()

    // MARK: - Computed Properties

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

    var totalFormulae: Int {
        installedPackages.filter { $0.type == .formula }.count
    }

    var totalCasks: Int {
        installedPackages.filter { $0.type == .cask }.count
    }

    // MARK: - Data Loading

    func loadAll() {
        Task {
            guard ShellExecutor.isBrewInstalled() else {
                brewAvailable = false
                showError("Homebrew is not installed. Please install Homebrew from https://brew.sh and relaunch TapHouse.")
                return
            }
            brewAvailable = true
            await loadInstalled()
            await loadOutdated()
            await loadBrewVersion()
            startBackgroundUpdateChecking()
        }
    }

    /// Periodically check for outdated packages in the background.
    func startBackgroundUpdateChecking() {
        backgroundCheckTask?.cancel()
        backgroundCheckTask = Task {
            while !Task.isCancelled {
                let interval = UserDefaults.standard.integer(forKey: AppSettingsKeys.updateCheckInterval)
                let seconds = interval > 0 ? interval : 3600
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { break }
                await loadOutdated()
            }
        }
    }

    func loadInstalled() async {
        isLoadingInstalled = true
        defer { isLoadingInstalled = false }

        do {
            installedPackages = try await brewService.listInstalled()
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

    // MARK: - Package Operations

    func install(_ package: BrewPackage) {
        runOperation(command: "install", package: package) { [weak self] onOutput in
            try await self?.brewService.install(
                package.name,
                isCask: package.type == .cask,
                onOutput: onOutput
            )
        }
    }

    func upgrade(_ package: BrewPackage) {
        runOperation(command: "upgrade", package: package) { [weak self] onOutput in
            try await self?.brewService.upgrade(
                package.name,
                isCask: package.type == .cask,
                onOutput: onOutput
            )
        }
    }

    func uninstall(_ package: BrewPackage) {
        runOperation(command: "uninstall", package: package) { [weak self] onOutput in
            try await self?.brewService.uninstall(
                package.name,
                isCask: package.type == .cask,
                onOutput: onOutput
            )
        }
    }

    func upgradeAll() {
        let op = BrewOperation(command: "upgrade --all", packageName: "All Packages")
        runOperation(operation: op) { [weak self] onOutput in
            try await self?.brewService.upgradeAll(onOutput: onOutput)
        }
    }

    func updateBrew() {
        let op = BrewOperation(command: "update", packageName: "Homebrew")
        runOperation(operation: op) { [weak self] onOutput in
            try await self?.brewService.update(onOutput: onOutput)
        }
    }

    /// Cancel the currently running operation.
    func cancelOperation() {
        runningTask?.cancel()
        runningTask = nil
    }

    /// Dismiss the completed/cancelled operation banner.
    func dismissOperation() {
        activeOperation = nil
    }

    // MARK: - Private

    private func runOperation(command: String, package: BrewPackage, action: @escaping (@escaping @Sendable (String) -> Void) async throws -> Void) {
        let op = BrewOperation(command: command, packageName: package.name)
        runOperation(operation: op, action: action)
    }

    private func runOperation(operation: BrewOperation, action: @escaping (@escaping @Sendable (String) -> Void) async throws -> Void) {
        let capturedSelf = self

        activeOperation = operation

        runningTask = Task {
            do {
                try await action { text in
                    Task { @MainActor in
                        capturedSelf.activeOperation?.output += text
                        // Cap output to prevent unbounded memory growth
                        if let output = capturedSelf.activeOperation?.output,
                           output.count > AppViewModel.maxOutputSize {
                            let trimmed = String(output.suffix(AppViewModel.maxOutputSize))
                            capturedSelf.activeOperation?.output = "… (output trimmed)\n" + trimmed
                        }
                    }
                }
                await MainActor.run {
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

            await MainActor.run {
                if var op = capturedSelf.activeOperation {
                    // Trim output for archival to save memory
                    if op.output.count > 500 {
                        op.output = String(op.output.suffix(500))
                    }
                    capturedSelf.operationHistory.insert(op, at: 0)
                    // Keep only last 20 operations
                    if capturedSelf.operationHistory.count > 20 {
                        capturedSelf.operationHistory = Array(capturedSelf.operationHistory.prefix(20))
                    }
                }
                capturedSelf.runningTask = nil
            }

            // Refresh data after operation
            await loadInstalled()
            await loadOutdated()
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

