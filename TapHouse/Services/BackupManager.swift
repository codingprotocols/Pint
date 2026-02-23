//
//  BackupManager.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 23/02/26.
//

import Foundation
import Combine

/// Manages export, import, and iCloud sync of installed package lists.
@MainActor
final class BackupManager: ObservableObject {

    // MARK: - Data Model

    struct PackageEntry: Codable, Identifiable, Hashable {
        var id: String { "\(type)-\(name)" }
        let name: String
        let type: String  // "formula" or "cask"
        let version: String
    }

    struct Backup: Codable {
        let appVersion: String
        let exportDate: String
        let packages: [PackageEntry]
    }

    // MARK: - Export

    /// Generate a JSON backup of the given packages.
    func exportJSON(packages: [BrewPackage]) -> Data? {
        let entries = packages.map {
            PackageEntry(name: $0.name, type: $0.type.rawValue, version: $0.version)
        }
        let backup = Backup(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            exportDate: ISO8601DateFormatter().string(from: Date()),
            packages: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }

    /// Generate a Brewfile-compatible string.
    func exportBrewfile(packages: [BrewPackage]) -> String {
        var lines: [String] = []
        lines.append("# TapHouse Brewfile")
        lines.append("# Exported on \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))")
        lines.append("")

        let formulae = packages.filter { $0.type == .formula }.sorted { $0.name < $1.name }
        let casks = packages.filter { $0.type == .cask }.sorted { $0.name < $1.name }

        if !formulae.isEmpty {
            lines.append("# Formulae")
            for pkg in formulae {
                lines.append("brew \"\(pkg.name)\"")
            }
            lines.append("")
        }

        if !casks.isEmpty {
            lines.append("# Casks")
            for pkg in casks {
                lines.append("cask \"\(pkg.name)\"")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Import

    /// Parse a JSON backup file.
    func importJSON(data: Data) -> [PackageEntry]? {
        guard let backup = try? JSONDecoder().decode(Backup.self, from: data) else { return nil }
        return backup.packages
    }

    /// Parse a Brewfile.
    func importBrewfile(content: String) -> [PackageEntry] {
        var entries: [PackageEntry] = []
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("brew \"") {
                let name = trimmed
                    .replacingOccurrences(of: "brew \"", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    entries.append(PackageEntry(name: name, type: "formula", version: ""))
                }
            } else if trimmed.hasPrefix("cask \"") {
                let name = trimmed
                    .replacingOccurrences(of: "cask \"", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    entries.append(PackageEntry(name: name, type: "cask", version: ""))
                }
            }
        }
        return entries
    }
}

