//
//  AppNavigationState.swift
//  Pint
//
//  Created by Ajeet Yadav on 22/02/26.
//

import Foundation

/// Owns all navigation and installed-list filter state.
/// Extracted from AppViewModel so navigation concerns are isolated from
/// package data and brew operations. Injected into the environment alongside
/// AppViewModel; views access it via AppViewModel's forwarding properties and
/// are unaffected by the extraction.
@Observable
@MainActor
final class AppNavigationState {
    var selectedNav: NavigationItem = .dashboard
    var installedFilter: PackageType? = nil
    var installedSearchText: String = ""
}
