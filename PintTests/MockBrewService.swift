//
//  MockBrewService.swift
//  PintTests
//

import Foundation
@testable import Pint

/// Minimal stub that returns empty results for every method.
/// Per-test customisation is done by setting the `stubbed*` properties
/// or flipping `shouldThrowBrewNotFound`.
final class MockBrewService: BrewServiceProtocol {

    var stubbedInstalled: [BrewPackage] = []
    var stubbedOutdated: [BrewPackage] = []
    var shouldThrowBrewNotFound = false
    var upgradeAllError: Error? = nil

    var installMultipleCalledNames: [[String]] = []
    var installMultipleCalledIsCask: [Bool] = []

    var stubbedReleaseNote: ReleaseNote? = nil
    var fetchReleaseNotesCalledWith: String? = nil

    var listServicesCalled = false
    var listTapsCalled = false

    // Call counters
    var listInstalledCallCount = 0

    func listInstalled() async throws -> [BrewPackage] {
        listInstalledCallCount += 1
        if shouldThrowBrewNotFound { throw ShellError.brewNotFound }
        return stubbedInstalled
    }
    func listOutdated() async throws -> [BrewPackage] {
        if shouldThrowBrewNotFound { throw ShellError.brewNotFound }
        return stubbedOutdated
    }
    func search(_ query: String) async throws -> [BrewPackage] { [] }
    func getInfo(_ name: String, type: PackageType) async throws -> BrewPackage {
        throw ShellError.brewNotFound
    }
    func install(_ name: String, isCask: Bool, onOutput: @escaping @Sendable (String) -> Void) async throws {}
    func upgrade(_ name: String, isCask: Bool, onOutput: @escaping @Sendable (String) -> Void) async throws {}
    func upgradeAll(onOutput: @escaping @Sendable (String) -> Void) async throws {
        if let error = upgradeAllError { throw error }
    }
    func uninstall(_ name: String, isCask: Bool, onOutput: @escaping @Sendable (String) -> Void) async throws {}
    func update(onOutput: @escaping @Sendable (String) -> Void) async throws {}
    func cleanupCache(onOutput: @escaping @Sendable (String) -> Void) async throws {}
    func getDiskUsage() async throws -> String { "" }
    func doctor() async throws -> String { "" }
    func version() async throws -> String { "" }
    func getDependencyTree(_ name: String) async throws -> String { "" }
    func listServices() async throws -> [BrewServiceItem] {
        listServicesCalled = true
        return []
    }
    func startService(_ name: String) async throws {}
    func stopService(_ name: String) async throws {}
    func restartService(_ name: String) async throws {}
    func listTaps() async throws -> [String] {
        listTapsCalled = true
        return []
    }
    func addTap(_ name: String, onOutput: @escaping @Sendable (String) -> Void) async throws {}
    func removeTap(_ name: String, onOutput: @escaping @Sendable (String) -> Void) async throws {}
    func pin(_ name: String) async throws {}
    func unpin(_ name: String) async throws {}
    func autoremove(onOutput: @escaping @Sendable (String) -> Void) async throws {}
    func installMultiple(_ names: [String], isCask: Bool, onOutput: @escaping @Sendable (String) -> Void) async throws {
        installMultipleCalledNames.append(names)
        installMultipleCalledIsCask.append(isCask)
    }
    func prefetchSearchLists() async {}
    func invalidateSearchCache() async {}
    func fetchReleaseNotes(homepage: String) async -> ReleaseNote? {
        fetchReleaseNotesCalledWith = homepage
        return stubbedReleaseNote
    }
}
