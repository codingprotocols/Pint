//
//  BrewPackage.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import Foundation

/// Represents whether a package is a formula or a cask.
enum PackageType: String, Codable, CaseIterable {
    case formula
    case cask
}

/// Core model representing a Homebrew package.
struct BrewPackage: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    var version: String
    var description: String
    var homepage: String
    var type: PackageType
    var isOutdated: Bool
    var currentVersion: String?
    var latestVersion: String?
    var installedOnRequest: Bool

    nonisolated init(
        name: String,
        version: String = "",
        description: String = "",
        homepage: String = "",
        type: PackageType = .formula,
        isOutdated: Bool = false,
        currentVersion: String? = nil,
        latestVersion: String? = nil,
        installedOnRequest: Bool = true
    ) {
        self.id = "\(type.rawValue)-\(name)"
        self.name = name
        self.version = version
        self.description = description
        self.homepage = homepage
        self.type = type
        self.isOutdated = isOutdated
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.installedOnRequest = installedOnRequest
    }
}

/// Represents the overall Homebrew status.
struct BrewStatus {
    var totalFormulae: Int = 0
    var totalCasks: Int = 0
    var outdatedCount: Int = 0
    var lastUpdated: Date?
    var brewVersion: String = ""
    var doctorIssues: [String] = []
}

/// Represents an active brew operation.
struct BrewOperation: Identifiable {
    let id = UUID()
    let command: String
    let packageName: String
    var output: String = ""
    var isComplete: Bool = false
    var isSuccess: Bool = true
    var startTime: Date = Date()
}

/// Release notes fetched from GitHub Releases API.
struct ReleaseNote: Sendable {
    let tagName: String
    let title: String
    let body: String
    let publishedAt: String
    let htmlURL: String
}
