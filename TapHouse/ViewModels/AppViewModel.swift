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
    case doctor = "Brew Doctor"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .installed: return "shippingbox.fill"
        case .upgrades: return "arrow.up.circle.fill"
        case .search: return "magnifyingglass"
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

    var isLoadingInstalled: Bool = false
    var isLoadingOutdated: Bool = false
    var isSearching: Bool = false
    var isLoadingDoctor: Bool = false

    // Operation tracking
    var activeOperation: BrewOperation? = nil
    var showingTerminal: Bool = false
    var operationHistory: [BrewOperation] = []

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
            await loadInstalled()
            await loadOutdated()
            await loadBrewVersion()
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

    // MARK: - Private

    private func runOperation(command: String, package: BrewPackage, action: @escaping (@escaping @Sendable (String) -> Void) async throws -> Void) {
        let op = BrewOperation(command: command, packageName: package.name)
        runOperation(operation: op, action: action)
    }

    private func runOperation(operation: BrewOperation, action: @escaping (@escaping @Sendable (String) -> Void) async throws -> Void) {
        activeOperation = operation
        showingTerminal = true

        Task {
            do {
                try await action { [weak self] text in
                    Task { @MainActor in
                        self?.activeOperation?.output += text
                    }
                }
                activeOperation?.isComplete = true
                activeOperation?.isSuccess = true
            } catch {
                activeOperation?.isComplete = true
                activeOperation?.isSuccess = false
                activeOperation?.output += "\n❌ Error: \(error.localizedDescription)"
            }

            if let op = activeOperation {
                operationHistory.insert(op, at: 0)
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
