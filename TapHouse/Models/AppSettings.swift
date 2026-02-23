//
//  AppSettings.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 23/02/26.
//

import Foundation

/// Keys and defaults for user preferences stored via @AppStorage.
enum AppSettingsKeys {
    static let showMenuBarIcon = "showMenuBarIcon"
    static let launchAtLogin = "launchAtLogin"
    static let updateCheckInterval = "updateCheckInterval"
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
