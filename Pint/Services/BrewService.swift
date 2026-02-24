//
//  BrewService.swift
//  Pint
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

    // MARK: - Services

    /// List all Homebrew services using `brew services list --json`.
    func listServices() async throws -> [BrewServiceItem] {
        let output = try await ShellExecutor.run(["services", "list", "--json"])
        guard let data = output.data(using: .utf8) else { return [] }

        do {
            let servicesData = try JSONDecoder().decode([ServiceJSON].self, from: data)
            return servicesData.map { item in
                BrewServiceItem(
                    name: item.name,
                    status: BrewServiceItem.ServiceStatus(rawValue: item.status.lowercased()) ?? .unknown,
                    user: item.user,
                    file: item.file,
                    exitCode: item.exitCode
                )
            }
        } catch {
            // Fallback for older brew or parsing issues
            return try await listServicesFallback()
        }
    }

    private func listServicesFallback() async throws -> [BrewServiceItem] {
        let output = try await ShellExecutor.run(["services", "list"])
        var services: [BrewServiceItem] = []
        let lines = output.components(separatedBy: "\n").dropFirst() // Skip header

        for line in lines where !line.isEmpty {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }

            let name = parts[0]
            let status = parts[1].lowercased()
            let user = parts.count > 2 ? parts[2] : nil
            let file = parts.count > 3 ? parts[3] : nil

            services.append(BrewServiceItem(
                name: name,
                status: BrewServiceItem.ServiceStatus(rawValue: status) ?? .unknown,
                user: user,
                file: file,
                exitCode: nil
            ))
        }
        return services
    }

    func startService(_ name: String) async throws {
        _ = try await ShellExecutor.run(["services", "start", name])
    }

    func stopService(_ name: String) async throws {
        _ = try await ShellExecutor.run(["services", "stop", name])
    }

    func restartService(_ name: String) async throws {
        _ = try await ShellExecutor.run(["services", "restart", name])
    }

    // MARK: - Taps

    /// List all Homebrew taps.
    func listTaps() async throws -> [String] {
        let output = try await ShellExecutor.run(["tap"])
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    /// Add a new tap.
    func addTap(_ name: String, onOutput: @escaping @Sendable (String) -> Void) async throws {
        try await ShellExecutor.runStreaming(["tap", name], onOutput: onOutput)
    }

    /// Remove an existing tap.
    func removeTap(_ name: String, onOutput: @escaping @Sendable (String) -> Void) async throws {
        try await ShellExecutor.runStreaming(["untap", name], onOutput: onOutput)
    }

    // MARK: - Diagnostics

    /// Get Homebrew disk usage in human-readable format.
    func getDiskUsage() async throws -> String {
        // Run du -sh on brew --cache and brew --prefix
        let cachePath = try await ShellExecutor.run(["--cache"])
        let output = try await ShellExecutor.runCustom("/usr/bin/du", arguments: ["-sh", cachePath.trimmingCharacters(in: .whitespacesAndNewlines)])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Clean up Homebrew cache.
    func cleanupCache(onOutput: @escaping @Sendable (String) -> Void) async throws {
        try await ShellExecutor.runStreaming(["cleanup", "--prune=all"], onOutput: onOutput)
    }

    /// Get the dependency tree for a package.
    func getDependencyTree(_ name: String) async throws -> String {
        return try await ShellExecutor.run(["deps", "--tree", name])
    }

    private struct ServiceJSON: Codable {
        let name: String
        let status: String
        let user: String?
        let file: String?
        let exitCode: Int?

        enum CodingKeys: String, CodingKey {
            case name, status, user, file
            case exitCode = "exit_code"
        }
    }
}
