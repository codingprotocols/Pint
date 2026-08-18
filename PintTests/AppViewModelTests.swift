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

    // MARK: - Lock error friendly message

    func testUpgradeAll_lockError_showsFriendlyMessage() async throws {
        let mock = MockBrewService()
        mock.upgradeAllError = NSError(
            domain: "brew",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Command 'brew upgrade' failed (exit 1): Error: A 'brew upgrade' process has already locked /path/to/file.incomplete"]
        )
        let runner = OperationRunner()
        let vm = AppViewModel(brewService: mock, runner: runner)

        vm.upgradeAll()

        // Poll until the operation completes (max 1 s).
        for _ in 0..<50 {
            if runner.activeOperation?.isComplete == true { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        let output = runner.activeOperation?.output ?? ""
        XCTAssertTrue(
            output.contains("Homebrew is locked by another process"),
            "Expected friendly lock message, got: \(output)"
        )
        XCTAssertFalse(
            output.contains("❌ Error:"),
            "Lock errors should not use the raw ❌ error format"
        )
        XCTAssertEqual(runner.activeOperation?.isSuccess, false)
    }

    func testBulkInstallFromBackup_formulaeOnly_allInstalledInOneBatch() async throws {
        let mock = MockBrewService()
        let runner = OperationRunner()
        let vm = AppViewModel(brewService: mock, runner: runner)

        let entries = [
            BackupManager.PackageEntry(name: "wget", type: "formula", version: ""),
            BackupManager.PackageEntry(name: "curl", type: "formula", version: ""),
        ]
        vm.bulkInstallFromBackup(entries)

        for _ in 0..<100 {
            if runner.activeOperation?.isComplete == true { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTAssertEqual(mock.installMultipleCalledNames.count, 1,
                       "All formulae must be batched into a single installMultiple call")
        XCTAssertEqual(Set(mock.installMultipleCalledNames[0]), Set(["wget", "curl"]))
        XCTAssertFalse(mock.installMultipleCalledIsCask[0])
    }

    func testBulkInstallFromBackup_casksOnly_installedWithIsCaskTrue() async throws {
        let mock = MockBrewService()
        let runner = OperationRunner()
        let vm = AppViewModel(brewService: mock, runner: runner)

        let entries = [
            BackupManager.PackageEntry(name: "firefox", type: "cask", version: ""),
        ]
        vm.bulkInstallFromBackup(entries)

        for _ in 0..<100 {
            if runner.activeOperation?.isComplete == true { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTAssertEqual(mock.installMultipleCalledNames.count, 1)
        XCTAssertEqual(mock.installMultipleCalledNames[0], ["firefox"])
        XCTAssertTrue(mock.installMultipleCalledIsCask[0])
    }

    func testBulkInstallFromBackup_emptyList_doesNotStartOperation() async throws {
        let mock = MockBrewService()
        let runner = OperationRunner()
        let vm = AppViewModel(brewService: mock, runner: runner)

        vm.bulkInstallFromBackup([])

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertFalse(runner.isOperationRunning)
        XCTAssertTrue(mock.installMultipleCalledNames.isEmpty)
    }

    func testFetchReleaseNotes_routedThroughService() async {
        let mock = MockBrewService()
        mock.stubbedReleaseNote = ReleaseNote(
            tagName: "v2.0", title: "Release 2.0",
            body: "Changes", publishedAt: "May 2026", htmlURL: "https://github.com/x/y/releases/tag/v2.0"
        )
        let vm = AppViewModel(brewService: mock)

        let note = await vm.fetchReleaseNotes(homepage: "https://github.com/owner/repo")

        XCTAssertEqual(note?.tagName, "v2.0")
        XCTAssertEqual(mock.fetchReleaseNotesCalledWith, "https://github.com/owner/repo")
    }

    func testFetchReleaseNotes_noRelease_returnsNil() async {
        let mock = MockBrewService()
        mock.stubbedReleaseNote = nil
        let vm = AppViewModel(brewService: mock)

        let note = await vm.fetchReleaseNotes(homepage: "https://github.com/owner/repo")

        XCTAssertNil(note)
    }


    // MARK: - bulkInstallFromSearch mixed types (Round-3 Bug 3)

    func testBulkInstallFromSearch_mixed_callsLoadInstalledOnce() async throws {
        let mock = MockBrewService()
        let runner = OperationRunner()
        let vm = AppViewModel(brewService: mock, runner: runner)

        let packages = [
            BrewPackage.make(name: "wget",    type: .formula),
            BrewPackage.make(name: "firefox", type: .cask),
        ]
        vm.bulkInstallFromSearch(packages)

        // Wait for both operations (formulae then casks) to complete
        for _ in 0..<200 {
            if mock.installMultipleCalledNames.count == 2 && !runner.isOperationRunning { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(mock.listInstalledCallCount, 1,
                       "loadInstalled() must be called exactly once after a mixed bulk install, not twice")
    }

    // MARK: - refreshCurrentView (.services)

    func testRefreshCurrentView_servicesNav_callsListServices() async throws {
        let mock = MockBrewService()
        let vm = AppViewModel(brewService: mock)
        vm.selectedNav = .services

        vm.refreshCurrentView()

        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(mock.listServicesCalled,
                      "refreshCurrentView() on .services must trigger loadServices()")
    }

    // MARK: - Tap trust (brew 6)

    func testLoadTaps_populatesTapsWithTrustMetadata() async {
        let mock = MockBrewService()
        mock.stubbedTaps = [
            BrewTap(name: "homebrew/core", isOfficial: true, isTrusted: true),
            BrewTap(name: "localstack/tap", isOfficial: false, isTrusted: false),
        ]
        let vm = AppViewModel(brewService: mock)

        await vm.loadTaps()

        XCTAssertTrue(mock.listTapsCalled)
        XCTAssertEqual(vm.taps.count, 2)
        XCTAssertEqual(vm.taps[1].name, "localstack/tap")
        XCTAssertFalse(vm.taps[1].isTrusted)
    }

    func testTrustTap_callsServiceAndReloadsTaps() async {
        let mock = MockBrewService()
        mock.stubbedTaps = [BrewTap(name: "localstack/tap", isOfficial: false, isTrusted: false)]
        let vm = AppViewModel(brewService: mock)
        await vm.loadTaps()

        // After trusting, the reload returns the updated state.
        mock.stubbedTaps = [BrewTap(name: "localstack/tap", isOfficial: false, isTrusted: true)]
        await vm.trustTap(vm.taps[0])

        XCTAssertEqual(mock.trustTapCalledWith, ["localstack/tap"])
        XCTAssertTrue(vm.taps[0].isTrusted)
    }

    func testUntrustTap_callsServiceAndReloadsTaps() async {
        let mock = MockBrewService()
        mock.stubbedTaps = [BrewTap(name: "mongodb/brew", isOfficial: false, isTrusted: true)]
        let vm = AppViewModel(brewService: mock)
        await vm.loadTaps()

        mock.stubbedTaps = [BrewTap(name: "mongodb/brew", isOfficial: false, isTrusted: false)]
        await vm.untrustTap(vm.taps[0])

        XCTAssertEqual(mock.untrustTapCalledWith, ["mongodb/brew"])
        XCTAssertFalse(vm.taps[0].isTrusted)
    }

    func testTrustTap_errorSurfacesAlert() async {
        let mock = MockBrewService()
        mock.trustTapError = ShellError.commandFailed(command: "brew trust", exitCode: 1, stderr: "boom")
        let vm = AppViewModel(brewService: mock)

        await vm.trustTap(BrewTap(name: "x/tap", isOfficial: false, isTrusted: false))

        XCTAssertTrue(vm.showError)
    }

    // MARK: - Installed on request (brew tab)

    func testSetInstalledOnRequest_updatesPackageInPlace() async {
        var pkg = BrewPackage.make(name: "wget", type: .formula)
        pkg.installedOnRequest = false
        let vm = makeViewModel(installed: [pkg])

        await vm.setInstalledOnRequest(vm.installedPackages[0], value: true)

        XCTAssertTrue(vm.installedPackages[0].installedOnRequest,
                      "Toggle must update the installed list in place, without a full reload")
    }

    func testSetInstalledOnRequest_recordsNameCaskAndValue() async {
        let mock = MockBrewService()
        mock.stubbedInstalled = [BrewPackage.make(name: "firefox", type: .cask)]
        let vm = AppViewModel(brewService: mock)
        await vm.loadInstalled()

        await vm.setInstalledOnRequest(vm.installedPackages[0], value: false)

        XCTAssertEqual(mock.setInstalledOnRequestCalls.count, 1)
        XCTAssertEqual(mock.setInstalledOnRequestCalls[0].name, "firefox")
        XCTAssertTrue(mock.setInstalledOnRequestCalls[0].isCask)
        XCTAssertFalse(mock.setInstalledOnRequestCalls[0].value)
        XCTAssertFalse(vm.installedPackages[0].installedOnRequest)
    }

    // MARK: - Background refresh (brew update-if-needed)

    func testPerformBackgroundUpdateCheck_usesUpdateIfNeeded() async {
        let mock = MockBrewService()
        mock.stubbedOutdated = [BrewPackage.make(name: "wget", type: .formula)]
        let vm = AppViewModel(brewService: mock)

        await vm.performBackgroundUpdateCheck()

        XCTAssertEqual(mock.updateIfNeededCallCount, 1)
        XCTAssertFalse(mock.updateCalled, "Background checks must use the cheap update-if-needed, not a full brew update")
        XCTAssertEqual(vm.outdatedPackages.count, 1)
    }

    func testPerformBackgroundUpdateCheck_successRecordsFreshnessTimestamp() async {
        UserDefaults.standard.removeObject(forKey: AppSettingsKeys.lastBrewUpdate)
        defer { UserDefaults.standard.removeObject(forKey: AppSettingsKeys.lastBrewUpdate) }
        let vm = AppViewModel(brewService: MockBrewService())

        await vm.performBackgroundUpdateCheck()

        XCTAssertNotNil(vm.lastBrewUpdateDate)
        XCTAssertFalse(vm.isBrewUpdateStale)
    }

    func testPerformBackgroundUpdateCheck_failedRefreshDoesNotRecordFreshness() async {
        UserDefaults.standard.removeObject(forKey: AppSettingsKeys.lastBrewUpdate)
        defer { UserDefaults.standard.removeObject(forKey: AppSettingsKeys.lastBrewUpdate) }
        let mock = MockBrewService()
        mock.updateIfNeededError = ShellError.commandFailed(
            command: "brew update-if-needed", exitCode: 1, stderr: "boom"
        )
        let vm = AppViewModel(brewService: mock)

        await vm.performBackgroundUpdateCheck()

        XCTAssertNil(vm.lastBrewUpdateDate,
                     "A failed database refresh must not be recorded as a successful update, "
                     + "otherwise isBrewUpdateStale would never fire again")
        XCTAssertTrue(vm.isBrewUpdateStale)
        // The outdated check still runs against the existing database.
        XCTAssertNotNil(vm.lastOutdatedCheck)
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
