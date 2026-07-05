//
//  BrewTap.swift
//  Pint
//

import Foundation

/// A Homebrew tap with brew 6 trust metadata.
struct BrewTap: Identifiable, Equatable {
    let name: String        // e.g. "localstack/tap"
    let isOfficial: Bool
    let isTrusted: Bool

    var id: String { name }
}
