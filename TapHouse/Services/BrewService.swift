//
//  BrewService.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import Foundation

/// Service that wraps Homebrew CLI interactions and the Homebrew JSON API.
@MainActor
final class BrewService {

    private let apiClient = BrewAPIClient.shared

    /// List all installed formulae and casks.
    func listInstalled() async throws -> [BrewPackage] {
        var packages: [BrewPackage] = []

        // Get installed formulae with JSON
        let formulaeJSON = try await ShellExecutor.run(["info", "--installed", "--json=v2"])
        packages.append(contentsOf: parseInstalledJSON(formulaeJSON))

        // Get installed casks
        let casksOutput = try await ShellExecutor.run(["list", "--cask", "--versions"])
        for line in casksOutput.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: " ")
            if let name = parts.first {
                let version = parts.dropFirst().joined(separator: " ")
                packages.append(BrewPackage(
                    name: name,
                    version: version,
                    type: .cask
                ))
            }
        }

        return packages.sorted { $0.name < $1.name }
    }

    /// Parse the JSON output from `brew info --installed --json=v2`.
    private func parseInstalledJSON(_ json: String) -> [BrewPackage] {
        guard let data = json.data(using: .utf8) else { return [] }

        var packages: [BrewPackage] = []

        do {
            if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let formulae = root["formulae"] as? [[String: Any]] {
                for formula in formulae {
                    let name = formula["name"] as? String ?? ""
                    let desc = formula["desc"] as? String ?? ""
                    let homepage = formula["homepage"] as? String ?? ""

                    var version = ""
                    var onRequest = true
                    if let installed = formula["installed"] as? [[String: Any]],
                       let first = installed.first {
                        version = first["version"] as? String ?? ""
                        onRequest = first["installed_on_request"] as? Bool ?? true
                    }

                    let outdated = formula["outdated"] as? Bool ?? false

                    var latest = ""
                    if let versions = formula["versions"] as? [String: Any] {
                        latest = versions["stable"] as? String ?? ""
                    }

                    packages.append(BrewPackage(
                        name: name,
                        version: version,
                        description: desc,
                        homepage: homepage,
                        type: .formula,
                        isOutdated: outdated,
                        currentVersion: version,
                        latestVersion: outdated ? latest : nil,
                        installedOnRequest: onRequest
                    ))
                }
            }
        } catch {
            // Fallback: parse simple list
        }

        return packages
    }

    /// List outdated packages.
    func listOutdated() async throws -> [BrewPackage] {
        let output = try await ShellExecutor.run(["outdated", "--json=v2"])
        guard let data = output.data(using: .utf8) else { return [] }

        var packages: [BrewPackage] = []

        do {
            if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let formulae = root["formulae"] as? [[String: Any]] {
                    for formula in formulae {
                        let name = formula["name"] as? String ?? ""
                        let currentVersion = (formula["installed_versions"] as? [String])?.first ?? ""
                        let latestVersion = formula["current_version"] as? String ?? ""

                        packages.append(BrewPackage(
                            name: name,
                            version: currentVersion,
                            type: .formula,
                            isOutdated: true,
                            currentVersion: currentVersion,
                            latestVersion: latestVersion
                        ))
                    }
                }
                if let casks = root["casks"] as? [[String: Any]] {
                    for cask in casks {
                        let name = cask["name"] as? String ?? ""
                        let currentVersion = cask["installed_versions"] as? String ?? ""
                        let latestVersion = cask["current_version"] as? String ?? ""

                        packages.append(BrewPackage(
                            name: name,
                            version: currentVersion,
                            type: .cask,
                            isOutdated: true,
                            currentVersion: currentVersion,
                            latestVersion: latestVersion
                        ))
                    }
                }
            }
        } catch {
            // ignore parse errors
        }

        return packages.sorted { $0.name < $1.name }
    }

    /// Search for packages by name using the Homebrew JSON API.
    func search(_ query: String) async throws -> [BrewPackage] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try await apiClient.search(query)
    }

    /// Get detailed info for a specific package using the Homebrew JSON API.
    func getInfo(_ name: String, type: PackageType = .formula) async throws -> BrewPackage {
        return try await apiClient.getInfo(name, type: type)
    }

    /// Install a package with streaming output.
    func install(_ name: String, isCask: Bool = false, onOutput: @escaping @Sendable (String) -> Void) async throws {
        var args = ["install", name]
        if isCask { args.insert("--cask", at: 1) }
        try await ShellExecutor.runStreaming(args, onOutput: onOutput)
    }

    /// Upgrade a specific package.
    func upgrade(_ name: String, isCask: Bool = false, onOutput: @escaping @Sendable (String) -> Void) async throws {
        var args = ["upgrade", name]
        if isCask { args.insert("--cask", at: 1) }
        try await ShellExecutor.runStreaming(args, onOutput: onOutput)
    }

    /// Upgrade all outdated packages.
    func upgradeAll(onOutput: @escaping @Sendable (String) -> Void) async throws {
        try await ShellExecutor.runStreaming(["upgrade"], onOutput: onOutput)
    }

    /// Uninstall a package.
    func uninstall(_ name: String, isCask: Bool = false, onOutput: @escaping @Sendable (String) -> Void) async throws {
        var args = ["uninstall", name]
        if isCask { args.insert("--cask", at: 1) }
        try await ShellExecutor.runStreaming(args, onOutput: onOutput)
    }

    /// Run brew update.
    func update(onOutput: @escaping @Sendable (String) -> Void) async throws {
        try await ShellExecutor.runStreaming(["update"], onOutput: onOutput)
    }

    /// Run brew doctor and return diagnostics.
    func doctor() async throws -> String {
        do {
            return try await ShellExecutor.run(["doctor"])
        } catch let error as ShellError {
            switch error {
            case .commandFailed(_, _, let stderr):
                return stderr
            default:
                throw error
            }
        }
    }

    /// Get brew version string.
    func version() async throws -> String {
        let output = try await ShellExecutor.run(["--version"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
