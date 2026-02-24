//
//  BrewServiceItem.swift
//  Pint
//
//  Created by Antigravity on 26/02/26.
//

import Foundation
import SwiftUI

/// Represents a service managed by Homebrew.
struct BrewServiceItem: Identifiable, Hashable, Sendable {
    let name: String
    let status: ServiceStatus
    let user: String?
    let file: String?
    let exitCode: Int?

    var id: String { name }

    enum ServiceStatus: String, Codable, Sendable {
        case started
        case stopped
        case error
        case unknown

        var color: Color {
            switch self {
            case .started: return .green
            case .stopped: return .secondary
            case .error: return .red
            case .unknown: return .orange
            }
        }

        var icon: String {
            switch self {
            case .started: return "play.fill"
            case .stopped: return "stop.fill"
            case .error: return "exclamationmark.triangle.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }
    }
}
