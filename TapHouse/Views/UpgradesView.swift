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
            // Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Available Upgrades")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    if viewModel.outdatedPackages.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("All packages are up to date!")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text("\(viewModel.outdatedPackages.count)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.orange.gradient))
                            Text("packages can be upgraded")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()

                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.loadOutdated() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(.callout.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)

                    if !viewModel.outdatedPackages.isEmpty {
                        Button {
                            viewModel.upgradeAll()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Upgrade All")
                            }
                            .font(.callout.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
            }
            .padding(24)

            Divider()

            if viewModel.isLoadingOutdated {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Checking for upgrades…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if viewModel.outdatedPackages.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [.green.opacity(0.15), .mint.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 80, height: 80)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(
                                LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                    Text("Everything is up to date!")
                        .font(.title2.weight(.semibold))
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
    }
}

struct UpgradePackageRow: View {
    let package: BrewPackage
    @Environment(AppViewModel.self) private var viewModel
    @State private var releaseNote: ReleaseNote?
    @State private var isLoadingRelease = false
    @State private var showReleaseNotes = false
    @State private var isHovered = false

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
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.2), .yellow.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(package.name)
                            .font(.body.weight(.semibold))
                        TypeBadge(type: package.type)
                    }

                    HStack(spacing: 6) {
                        Text(package.currentVersion ?? package.version)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(.red.opacity(0.1)))

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(package.latestVersion ?? "latest")
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(.green.opacity(0.1)))
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
                        Image(systemName: "doc.text")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.blue)
                    .help("Release Notes")
                }

                Button {
                    viewModel.upgrade(package)
                } label: {
                    Label("Upgrade", systemImage: "arrow.up.circle")
                        .font(.caption.weight(.medium))
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
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                )
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? AnyShapeStyle(.quaternary.opacity(0.5)) : AnyShapeStyle(.clear))
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in isHovered = hovering }
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
