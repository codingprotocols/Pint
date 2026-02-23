//
//  UpgradesView.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

struct UpgradesView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available Upgrades")
                        .font(.largeTitle.weight(.bold))
                    if viewModel.outdatedPackages.isEmpty {
                        Text("All packages are up to date!")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else {
                        Text("\(viewModel.outdatedPackages.count) packages can be upgraded")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()

                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.loadOutdated() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    if !viewModel.outdatedPackages.isEmpty {
                        Button {
                            viewModel.upgradeAll()
                        } label: {
                            Label("Upgrade All", systemImage: "arrow.up.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
            }
            .padding()

            Divider()

            if viewModel.isLoadingOutdated {
                Spacer()
                ProgressView("Checking for upgrades…")
                Spacer()
            } else if viewModel.outdatedPackages.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green.gradient)
                    Text("Everything is up to date!")
                        .font(.title2.weight(.medium))
                    Text("All your packages are on the latest version.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.outdatedPackages) { pkg in
                        UpgradePackageRow(package: pkg)
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(.background)
    }
}

struct UpgradePackageRow: View {
    let package: BrewPackage
    @Environment(AppViewModel.self) private var viewModel
    @State private var releaseNote: ReleaseNote?
    @State private var isLoadingRelease = false
    @State private var showReleaseNotes = false

    /// Look up homepage from installed packages (which have it) or fall back to the package's field.
    private var homepage: String {
        if let installed = viewModel.installedPackages.first(where: { $0.name == package.name }),
           !installed.homepage.isEmpty {
            return installed.homepage
        }
        return package.homepage
    }

    private var hasGitHubHomepage: Bool {
        homepage.contains("github.com")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange.gradient)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(package.name)
                            .font(.body.weight(.medium))
                        TypeBadge(type: package.type)
                    }

                    HStack(spacing: 6) {
                        Text(package.currentVersion ?? package.version)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(package.latestVersion ?? "latest")
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Spacer()

                // Release notes toggle
                if hasGitHubHomepage {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showReleaseNotes.toggle()
                        }
                        if showReleaseNotes && releaseNote == nil && !isLoadingRelease {
                            loadReleaseNotes()
                        }
                    } label: {
                        Label("Notes", systemImage: "doc.text")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.blue)
                }

                Button {
                    viewModel.upgrade(package)
                } label: {
                    Label("Upgrade", systemImage: "arrow.up.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            }
            .padding(.vertical, 6)

            // Expandable release notes
            if showReleaseNotes {
                VStack(alignment: .leading, spacing: 8) {
                    if isLoadingRelease {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading release notes…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if let release = releaseNote {
                        HStack(spacing: 8) {
                            Text(release.tagName)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1))
                                .clipShape(Capsule())

                            if !release.publishedAt.isEmpty {
                                Text(release.publishedAt)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            if let url = URL(string: release.htmlURL), !release.htmlURL.isEmpty {
                                Link(destination: url) {
                                    Label("GitHub", systemImage: "arrow.up.right.square")
                                        .font(.caption2)
                                }
                            }
                        }

                        Text(release.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("No release notes available.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 4)
                    }
                }
                .padding(12)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func loadReleaseNotes() {
        isLoadingRelease = true
        Task {
            let note = await BrewAPIClient.shared.fetchReleaseNotes(homepage: homepage)
            await MainActor.run {
                releaseNote = note
                isLoadingRelease = false
            }
        }
    }
}
