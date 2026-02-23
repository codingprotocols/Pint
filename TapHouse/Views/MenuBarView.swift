//
//  MenuBarView.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 23/02/26.
//

import SwiftUI

/// The popover content shown when clicking the menu bar icon.
struct MenuBarView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "mug.fill")
                    .foregroundStyle(.orange.gradient)
                Text("TapHouse")
                    .font(.headline)
                Spacer()
                if viewModel.isLoadingOutdated {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(12)

            Divider()

            // Status
            if viewModel.outdatedPackages.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("All packages are up to date")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            } else {
                // Outdated packages list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.outdatedPackages.prefix(10)) { pkg in
                            MenuBarPackageRow(package: pkg)
                            if pkg.id != viewModel.outdatedPackages.prefix(10).last?.id {
                                Divider().padding(.horizontal, 12)
                            }
                        }

                        if viewModel.outdatedPackages.count > 10 {
                            Text("+ \(viewModel.outdatedPackages.count - 10) more…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(8)
                        }
                    }
                }
                .frame(maxHeight: 320)

                Divider()

                // Upgrade All button
                Button {
                    viewModel.upgradeAll()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Upgrade All (\(viewModel.outdatedPackages.count))")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(12)
                .background(.orange.opacity(0.08))
            }

            Divider()

            // Footer actions
            VStack(spacing: 0) {
                Button {
                    Task { await viewModel.loadOutdated() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Check for Updates")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                Button {
                    showMainWindow()
                } label: {
                    HStack {
                        Image(systemName: "macwindow")
                        Text("Open TapHouse")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit TapHouse")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 300)
    }

    private func showMainWindow() {
        // Restore dock icon first
        NSApp.setActivationPolicy(.regular)

        // Try to find and show an existing main window
        var found = false
        for window in NSApp.windows {
            if window.canBecomeMain && !(window.title.isEmpty && window.level == .statusBar) {
                window.makeKeyAndOrderFront(nil)
                found = true
                break
            }
        }

        // If no window found, open a new one via WindowGroup ID
        if !found {
            openWindow(id: "main")
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Menu Bar Package Row

struct MenuBarPackageRow: View {
    let package: BrewPackage
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(package.name)
                    .font(.callout.weight(.medium))
                HStack(spacing: 4) {
                    Text(package.currentVersion ?? package.version)
                        .foregroundStyle(.red.opacity(0.8))
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(package.latestVersion ?? "latest")
                        .foregroundStyle(.green)
                }
                .font(.caption2)
            }

            Spacer()

            Button {
                viewModel.upgrade(package)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .help("Upgrade \(package.name)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
