//
//  CheckForUpdatesView.swift
//  Pint
//

import Combine
import Sparkle
import SwiftUI

// MARK: - UpdaterObserver

/// Bridges SPUUpdater.canCheckForUpdates (KVO) into a SwiftUI-observable property.
/// Lives as an ObservableObject because SPUUpdater is ObjC and predates @Observable.
private final class UpdaterObserver: ObservableObject {
    @Published var canCheckForUpdates = false
    private var cancellable: AnyCancellable?

    init(updater: SPUUpdater) {
        cancellable = updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: \.canCheckForUpdates, on: self)
    }
}

// MARK: - CheckForUpdatesView

/// A "Check for Updates…" menu command that mirrors the enabled state of the
/// underlying Sparkle updater. Drop into a `CommandGroup(after: .appInfo)`.
struct CheckForUpdatesView: View {
    private let updater: SPUUpdater
    @StateObject private var observer: UpdaterObserver

    init(updater: SPUUpdater) {
        self.updater = updater
        _observer = StateObject(wrappedValue: UpdaterObserver(updater: updater))
    }

    var body: some View {
        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!observer.canCheckForUpdates)
    }
}
