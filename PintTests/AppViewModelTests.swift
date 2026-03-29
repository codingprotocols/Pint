//
//  AppViewModelTests.swift
//  PintTests
//
//  Tests AppViewModel computed properties, metadata sync, error handling, and
//  OperationRunner's history cap — all without a real brew binary.
//
//  All test methods are `async` so XCTest hops to MainActor before calling
//  into @MainActor-isolated code (AppViewModel, OperationRunner). Non-async
//  test methods on a @MainActor class are called via ObjC dispatch, which
//  bypasses Swift's actor-isolation runtime check and crashes the host app.
//

import XCTest
@testable import Pint

@MainActor
final class AppViewModelTests: XCTestCase {

    // MARK: - filteredInstalled

    func testFilteredInstalled_noFilter_returnsAll() async {
        let vm = makeViewModel(installed: [
            .make(name: "wget", type: .formula),
            .make(name: "firefox", type: .cask),
        ])
        XCTAssertEqual(vm.filteredInstalled.count, 2)
    }

    func testFilteredInstalled_formulaFilter() async {
        let vm = makeViewModel(installed: [
            .make(name: "wget", type: .formula),
            .make(name: "firefox", type: .cask),
            .make(name: "curl", type: .formula),
        ])
        vm.installedFilter = .formula
        XCTAssertEqual(vm.filteredInstalled.count, 2)
        XCTAssertTrue(vm.filteredInstalled.allSatisfy { $0.type == .formula })
    }

    func testFilteredInstalled_caskFilter() async {
        let vm = makeViewModel(installed: [
            .make(name: "wget", type: .formula),
            .make(name: "firefox", type: .cask),
        ])
        vm.installedFilter = .cask
        XCTAssertEqual(vm.filteredInstalled.count, 1)
        XCTAssertEqual(vm.filteredInstalled[0].name, "firefox")
    }

    func testFilteredInstalled_searchText_caseInsensitive() async {
        let vm = makeViewModel(installed: [
            .make(name: "wget", type: .formula),
            .make(name: "Wget-extra", type: .formula),
            .make(name: "curl", type: .formula),
        ])
        vm.installedSearchText = "wget"
        XCTAssertEqual(vm.filteredInstalled.count, 2)
    }

    func testFilteredInstalled_searchAndTypeFilter_combined() async {
        let vm = makeViewModel(installed: [
            .make(name: "wget", type: .formula),
            .make(name: "wget-cask", type: .cask),
        ])
        vm.installedSearchText = "wget"
        vm.installedFilter = .formula
        XCTAssertEqual(vm.filteredInstalled.count, 1)
        XCTAssertEqual(vm.filteredInstalled[0].type, .formula)
    }

    // MARK: - upgradablePackages / pinnedOutdatedCount

    func testUpgradablePackages_excludesPinnedFormulae() async {
        let pinned   = BrewPackage.make(name: "openssl", type: .formula, isPinned: true)
        let unpinned = BrewPackage.make(name: "curl",    type: .formula, isPinned: false)
        let cask     = BrewPackage.make(name: "firefox", type: .cask)
        let vm = makeViewModel(
            installed: [pinned, unpinned, cask],
            outdated:  [
                .make(name: "openssl", type: .formula, isOutdated: true),
                .make(name: "curl",    type: .formula, isOutdated: true),
                .make(name: "firefox", type: .cask,    isOutdated: true),
            ]
        )
        let upgradable = vm.upgradablePackages
        XCTAssertEqual(upgradable.count, 2)
        XCTAssertFalse(upgradable.contains { $0.name == "openssl" })
    }

    func testUpgradablePackages_pinnedCasks_areAlwaysUpgradable() async {
        // Brew does not support pinning casks; a cask that appears pinned in the model
        // should still be treated as upgradable (pin is formulae-only).
        let cask = BrewPackage.make(name: "firefox", type: .cask, isPinned: true)
        let vm = makeViewModel(
            installed: [cask],
            outdated:  [.make(name: "firefox", type: .cask, isOutdated: true)]
        )
        XCTAssertEqual(vm.upgradablePackages.count, 1)
    }

    func testPinnedOutdatedCount() async {
        let pinned   = BrewPackage.make(name: "openssl", type: .formula, isPinned: true)
        let unpinned = BrewPackage.make(name: "curl",    type: .formula, isPinned: false)
        let vm = makeViewModel(
            installed: [pinned, unpinned],
            outdated:  [
                .make(name: "openssl", type: .formula, isOutdated: true),
                .make(name: "curl",    type: .formula, isOutdated: true),
            ]
        )
        XCTAssertEqual(vm.pinnedOutdatedCount, 1)
    }

    // MARK: - toggleFavorite / updateNotes / applyMetadata

    func testToggleFavorite_syncsBothArrays() async {
        let pkg = BrewPackage.make(name: "wget", type: .formula)
        let vm = makeViewModel(installed: [pkg], searchResults: [pkg])

        vm.toggleFavorite(pkg)

        XCTAssertTrue(vm.installedPackages.first { $0.name == "wget" }?.isFavorite == true)
        XCTAssertTrue(vm.searchResults.first     { $0.name == "wget" }?.isFavorite == true)
    }

    func testToggleFavorite_roundTrip() async {
        let pkg = BrewPackage.make(name: "wget", type: .formula)
        let vm = makeViewModel(installed: [pkg])

        vm.toggleFavorite(pkg)
        XCTAssertTrue(vm.installedPackages[0].isFavorite)

        vm.toggleFavorite(vm.installedPackages[0])
        XCTAssertFalse(vm.installedPackages[0].isFavorite)
    }

    func testUpdateNotes_syncsBothArrays() async {
        let pkg = BrewPackage.make(name: "wget", type: .formula)
        let vm = makeViewModel(installed: [pkg], searchResults: [pkg])

        vm.updateNotes(pkg, notes: "my note")

        XCTAssertEqual(vm.installedPackages.first { $0.name == "wget" }?.notes, "my note")
        XCTAssertEqual(vm.searchResults.first     { $0.name == "wget" }?.notes, "my note")
    }

    func testUpdateNotes_preservesFavoriteFlag() async {
        let pkg = BrewPackage.make(name: "wget", type: .formula)
        let vm = makeViewModel(installed: [pkg])

        vm.toggleFavorite(pkg)
        XCTAssertTrue(vm.installedPackages[0].isFavorite)

        vm.updateNotes(vm.installedPackages[0], notes: "note text")
        XCTAssertTrue(vm.installedPackages[0].isFavorite, "Favorite flag must survive updateNotes")
    }

    func testToggleFavorite_preservesNotes() async {
        let pkg = BrewPackage.make(name: "wget", type: .formula)
        let vm = makeViewModel(installed: [pkg])

        vm.updateNotes(pkg, notes: "keep me")
        vm.toggleFavorite(vm.installedPackages[0])
        XCTAssertEqual(vm.installedPackages[0].notes, "keep me", "Notes must survive toggleFavorite")
    }

    // MARK: - brewNotFound → silent failure (Issue 3)

    func testLoadInstalled_brewNotFound_setsBoolFalse_noAlert() async {
        let mock = MockBrewService()
        mock.shouldThrowBrewNotFound = true
        let vm = AppViewModel(brewService: mock)
        vm.brewAvailable = true

        await vm.loadInstalled()

        XCTAssertFalse(vm.brewAvailable)
        XCTAssertFalse(vm.showError, "brewNotFound must not surface a blocking alert")
    }

    func testLoadOutdated_brewNotFound_setsBoolFalse_noAlert() async {
        let mock = MockBrewService()
        mock.shouldThrowBrewNotFound = true
        let vm = AppViewModel(brewService: mock)
        vm.brewAvailable = true

        await vm.loadOutdated()

        XCTAssertFalse(vm.brewAvailable)
        XCTAssertFalse(vm.showError)
    }

    // MARK: - OperationRunner history cap (Issue 4)

    func testOperationHistory_cappedAt20() async throws {
        let runner = OperationRunner()

        for i in 0..<25 {
            runner.run(
                operation: BrewOperation(command: "test", packageName: "\(i)"),
                action: { _ in }
            )
            // Poll until the fast no-op action finishes before starting the next.
            while runner.isOperationRunning {
                try await Task.sleep(nanoseconds: 1_000_000) // 1 ms
            }
        }

        XCTAssertEqual(runner.operationHistory.count, 20,
                       "History must be capped at 20 to prevent unbounded memory growth")
    }

    func testOperationHistory_mostRecentFirst() async throws {
        let runner = OperationRunner()

        for i in 0..<3 {
            runner.run(
                operation: BrewOperation(command: "op", packageName: "pkg-\(i)"),
                action: { _ in }
            )
            while runner.isOperationRunning {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
        }

        XCTAssertEqual(runner.operationHistory.first?.packageName, "pkg-2",
                       "Most recent operation must be at index 0")
    }

    // MARK: - Helpers

    private func makeViewModel(
        installed: [BrewPackage] = [],
        outdated: [BrewPackage] = [],
        searchResults: [BrewPackage] = []
    ) -> AppViewModel {
        let mock = MockBrewService()
        mock.stubbedInstalled = installed
        mock.stubbedOutdated  = outdated
        let vm = AppViewModel(brewService: mock)
        vm.installedPackages = installed
        vm.outdatedPackages  = outdated
        vm.searchResults     = searchResults
        return vm
    }
}

// MARK: - BrewPackage test factory

extension BrewPackage {
    static func make(
        name: String,
        type: PackageType = .formula,
        isPinned: Bool = false,
        isOutdated: Bool = false
    ) -> BrewPackage {
        BrewPackage(name: name, type: type, isOutdated: isOutdated, isPinned: isPinned)
    }
}
