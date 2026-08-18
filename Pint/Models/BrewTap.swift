//
//  BrewTap.swift
//  Pint
//

import Foundation

/// A Homebrew tap with brew 6 trust metadata.
struct BrewTap: Identifiable, Equatable {
    let name: String        // e.g. "localstack/tap"
    let isOfficial: Bool

    /// Trust state as reported by brew. `nil` means the installed Homebrew
    /// does not report trust at all (brew < 6, or the `tap-info` query
    /// failed), which is deliberately *not* the same as "trusted" — the UI
    /// must hide trust affordances rather than claim an unknown tap is safe.
    let isTrusted: Bool?

    var id: String { name }

    /// True only when brew explicitly reports this tap as untrusted.
    var isKnownUntrusted: Bool { isTrusted == false }

    /// Whether trust actions (`brew trust` / `brew untrust`) are supported
    /// for this tap. Official taps are always trusted and cannot be changed.
    var supportsTrustActions: Bool { !isOfficial && isTrusted != nil }
}
