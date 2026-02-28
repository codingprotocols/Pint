//
//  AppSettings.swift
//  Pint
//
//  Created by Ajeet Yadav on 23/02/26.
//

import Foundation

/// Keys and defaults for user preferences stored via @AppStorage / UserDefaults.
enum AppSettingsKeys {
    static let showMenuBarIcon = "showMenuBarIcon"
    static let launchAtLogin = "launchAtLogin"
    static let updateCheckInterval = "updateCheckInterval"
    static let packageMetadata = "packageMetadata"
    static let operationHistory = "operationHistory"
    /// Optional GitHub personal access token stored in UserDefaults.
    /// Raises the GitHub API rate limit from 60 to 5 000 req/hr.
    static let githubToken = "githubToken"
    /// Unix timestamp (Double) of the last successful `brew update` run.
    static let lastBrewUpdate = "lastBrewUpdate"
    /// Bool — whether to send macOS notifications on operation completion / new updates.
    static let notificationsEnabled = "notificationsEnabled"
}

/// Available intervals for automatic update checking.
enum UpdateCheckInterval: Int, CaseIterable, Identifiable {
    case thirtyMinutes = 1800
    case oneHour = 3600
    case fourHours = 14400
    case eightHours = 28800
    case daily = 86400

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .thirtyMinutes: return "Every 30 minutes"
        case .oneHour: return "Every hour"
        case .fourHours: return "Every 4 hours"
        case .eightHours: return "Every 8 hours"
        case .daily: return "Every 24 hours"
        }
    }
}
