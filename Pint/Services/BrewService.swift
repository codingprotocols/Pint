//
//  BrewService.swift
//  Pint
//
//  Created by Ajeet Yadav on 22/02/26.
//

import Foundation
import OSLog

// MARK: - Protocol

/// Abstraction over Homebrew CLI interactions, primarily for testability.
protocol BrewServiceProtocol: AnyObject {
    func listInstalled() async throws -> [BrewPackage]
    func listOutdated() async throws -> [BrewPackage]
    func search(_ query: String) async throws -> [BrewPackage]
    func getInfo(_ name: String, type: PackageType) async throws -> BrewPackage
    func install(_ name: String, isCask: Bool, onOutput: @escaping @Sendable (String) -> Void) async throws
    func upgrade(_ name: String, isCask: Bool, onOutput: @escaping @Sendable (String) -> Void) async throws
    func upgradeAll(onOutput: @escaping @Sendable (String) -> Void) async throws
    func uninstall(_ name: String, isCask: Bool, onOutput: @escaping @Sendable (String) -> Void) async throws
    func update(onOutput: @escaping @Sendable (String) -> Void) async throws
    func cleanupCache(onOutput: @escaping @Sendable (String) -> Void) async throws
    func getDiskUsage() async throws -> String
    func doctor() async throws -> String
    func version() async throws -> String
    func getDependencyTree(_ name: String) async throws -> String
    func listServices() async throws -> [BrewServiceItem]
    func startService(_ name: String) async throws
    func stopService(_ name: String) async throws
    func restartService(_ name: String) async throws
    func listTaps() async throws -> [String]
    func addTap(_ name: String, onOutput: @escaping @Sendable (String) -> Void) async throws
    func removeTap(_ name: String, onOutput: @escaping @Sendable (String) -> Void) async throws
}

// MARK: - Codable Types (Homebrew JSON schema)

private struct BrewInfoOutput: Decodable {
    let formulae: [FormulaInfo]

    struct FormulaInfo: Decodable {
        let name: String
        let desc: String?
        let homepage: String?
        let installed: [InstalledVersion]
        let outdated: Bool
        let versions: FormulaVersions?

        struct InstalledVersion: Decodable {
            let version: String
            let installedOnRequest: Bool

            enum CodingKeys: String, CodingKey {
                case version
                case installedOnRequest = "installed_on_request"
            }
        }

        struct FormulaVersions: Decodable {
            let stable: String?
        }
    }
}

private struct BrewOutdatedOutput: Decodable {
    let formulae: [OutdatedFormula]
    let casks: [OutdatedCask]

    struct OutdatedFormula: Decodable {
        let name: String
        let installedVersions: [String]
        let currentVersion: String

        enum CodingKeys: String, CodingKey {
            case name
            case installedVersions = "installed_versions"
            case currentVersion = "current_version"
        }
    }

    struct OutdatedCask: Decodable {
        let name: String
        // Casks report a single string, not an array.
        let installedVersions: String
        let currentVersion: String

        enum CodingKeys: String, CodingKey {
            case name
            case installedVersions = "installed_versions"
            case currentVersion = "current_version"
        }
    }
}

// MARK: - Implementation

/// Wraps Homebrew CLI interactions and delegates API queries to `BrewAPIClientProtocol`.
final class BrewService: BrewServiceProtocol {

    private let logger = Logger(subsystem: "com.pint", category: "brew-service")
    private let apiClient: any BrewAPIClientProtocol

    init(apiClient: any BrewAPIClientProtocol = BrewAPIClient.shared) {
        self.apiClient = apiClient
    }

    // MARK: - Installed Packages

    /// List all installed formulae and casks in parallel.
    func listInstalled() async throws -> [BrewPackage] {
        // Fetch formulae (JSON) and casks (text) concurrently — halves load time.
        async let formulaeJSON = ShellExecutor.run(["info", "--installed", "--json=v2"])
        async let casksOutput = ShellExecutor.run(["list", "--cask", "--versions"])

        let (fJSON, cJSON) = try await (formulaeJSON, casksOutput)

        var packages: [BrewPackage] = []
        packages.append(contentsOf: parseInstalledFormulae(fJSON))
        packages.append(contentsOf: parseInstalledCasks(cJSON))
        return packages.sorted { $0.name < $1.name }
    }

    private func parseInstalledFormulae(_ json: String) -> [BrewPackage] {
        guard let data = json.data(using: .utf8) else { return [] }
        do {
            let output = try JSONDecoder().decode(BrewInfoOutput.self, from: data)
            return output.formulae.map { formula in
                let installed = formula.installed.first
                let version = installed?.version ?? ""
                let onRequest = installed?.installedOnRequest ?? true
                return BrewPackage(
                    name: formula.name,
                    version: version,
                    description: formula.desc ?? "",
                    homepage: formula.homepage ?? "",
                    type: .formula,
                    isOutdated: formula.outdated,
                    currentVersion: version,
                    latestVersion: formula.outdated ? formula.versions?.stable : nil,
                    installedOnRequest: onRequest
                )
            }
        } catch {
            logger.error("Failed to decode installed formulae JSON: \(error)")
            return []
        }
    }

    private func parseInstalledCasks(_ output: String) -> [BrewPackage] {
        output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> BrewPackage? in
                let parts = line.components(separatedBy: " ")
                guard let name = parts.first, !name.isEmpty else { return nil }
                let version = parts.dropFirst().joined(separator: " ")
                return BrewPackage(name: name, version: version, type: .cask)
            }
    }

    // MARK: - Outdated Packages

    func listOutdated() async throws -> [BrewPackage] {
        let output = try await ShellExecutor.run(["outdated", "--json=v2"])
        guard let data = output.data(using: .utf8) else { return [] }

        do {
            let decoded = try JSONDecoder().decode(BrewOutdatedOutput.self, from: data)
            var packages: [BrewPackage] = []

            for formula in decoded.formulae {
                let current = formula.installedVersions.first ?? ""
                packages.append(BrewPackage(
                    name: formula.name,
                    version: current,
                    type: .formula,
                    isOutdated: true,
                    currentVersion: current,
                    latestVersion: formula.currentVersion
                ))
            }

            for cask in decoded.casks {
                packages.append(BrewPackage(
                    name: cask.name,
                    version: cask.installedVersions,
                    type: .cask,
                    isOutdated: true,
                    currentVersion: cask.installedVersions,
                    latestVersion: cask.currentVersion
                ))
            }

            return packages.sorted { $0.name < $1.name }
        } catch {
            logger.error("Failed to decode outdated packages JSON: \(error)")
            return []
        }
    }

    // MARK: - Search & Info

    func search(_ query: String) async throws -> [BrewPackage] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try await apiClient.search(query)
    }

    func getInfo(_ name: String, type: PackageType = .formula) async throws -> BrewPackage {
        return try await apiClient.getInfo(name, type: type)
    }

    // MARK: - Operations (streaming)

    func install(_ name: String, isCask: Bool = false, onOutput: @escaping @Sendable (String) -> Void) async throws {
        var args = ["install", name]
        if isCask { args.insert("--cask", at: 1) }
        try await ShellExecutor.runStreaming(args, onOutput: onOutput)
    }

    func upgrade(_ name: String, isCask: Bool = false, onOutput: @escaping @Sendable (String) -> Void) async throws {
        var args = ["upgrade", name]
        if isCask { args.insert("--cask", at: 1) }
        try await ShellExecutor.runStreaming(args, onOutput: onOutput)
    }

    func upgradeAll(onOutput: @escaping @Sendable (String) -> Void) async throws {
        try await ShellExecutor.runStreaming(["upgrade"], onOutput: onOutput)
    }

    func uninstall(_ name: String, isCask: Bool = false, onOutput: @escaping @Sendable (String) -> Void) async throws {
        var args = ["uninstall", name]
        if isCask { args.insert("--cask", at: 1) }
        try await ShellExecutor.runStreaming(args, onOutput: onOutput)
    }

    func update(onOutput: @escaping @Sendable (String) -> Void) async throws {
        try await ShellExecutor.runStreaming(["update"], onOutput: onOutput)
    }

    // MARK: - Diagnostics

    func doctor() async throws -> String {
        do {
            return try await ShellExecutor.run(["doctor"])
        } catch let error as ShellError {
            switch error {
            case .commandFailed(_, _, let stderr): return stderr
            default: throw error
            }
        }
    }

    func version() async throws -> String {
        let output = try await ShellExecutor.run(["--version"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getDiskUsage() async throws -> String {
        let cachePath = try await ShellExecutor.run(["--cache"])
        let output = try await ShellExecutor.runCustom(
            "/usr/bin/du",
            arguments: ["-sh", cachePath.trimmingCharacters(in: .whitespacesAndNewlines)]
        )
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cleanupCache(onOutput: @escaping @Sendable (String) -> Void) async throws {
        try await ShellExecutor.runStreaming(["cleanup", "--prune=all"], onOutput: onOutput)
    }

    func getDependencyTree(_ name: String) async throws -> String {
        return try await ShellExecutor.run(["deps", "--tree", name])
    }

    // MARK: - Services

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
            logger.warning("JSON service list failed, falling back to text parsing: \(error)")
            return try await listServicesFallback()
        }
    }

    private func listServicesFallback() async throws -> [BrewServiceItem] {
        let output = try await ShellExecutor.run(["services", "list"])
        var services: [BrewServiceItem] = []
        let lines = output.components(separatedBy: "\n").dropFirst()

        for line in lines where !line.isEmpty {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }
            services.append(BrewServiceItem(
                name: parts[0],
                status: BrewServiceItem.ServiceStatus(rawValue: parts[1].lowercased()) ?? .unknown,
                user: parts.count > 2 ? parts[2] : nil,
                file: parts.count > 3 ? parts[3] : nil,
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

    func listTaps() async throws -> [String] {
        let output = try await ShellExecutor.run(["tap"])
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    func addTap(_ name: String, onOutput: @escaping @Sendable (String) -> Void) async throws {
        try await ShellExecutor.runStreaming(["tap", name], onOutput: onOutput)
    }

    func removeTap(_ name: String, onOutput: @escaping @Sendable (String) -> Void) async throws {
        try await ShellExecutor.runStreaming(["untap", name], onOutput: onOutput)
    }

    // MARK: - Private Codable Types

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
