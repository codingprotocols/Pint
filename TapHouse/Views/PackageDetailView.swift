//
//  PackageDetailView.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

struct PackageDetailView: View {
    let package: BrewPackage
    @Environment(AppViewModel.self) private var viewModel
    @State private var detailedPackage: BrewPackage?
    @State private var releaseNote: ReleaseNote?
    @State private var isLoadingRelease = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(package.type == .formula ? .green.opacity(0.15) : .purple.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: package.type == .formula ? "terminal.fill" : "macwindow")
                            .font(.title)
                            .foregroundStyle(package.type == .formula ? .green : .purple)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(package.name)
                                .font(.title.weight(.bold))
                            TypeBadge(type: package.type)
                        }
                        if let detail = detailedPackage {
                            Text(detail.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                LabeledContent("Version") {
                    Text(detailedPackage?.version ?? package.version)
                        .font(.system(.body, design: .monospaced))
                }

                if let homepage = detailedPackage?.homepage, !homepage.isEmpty {
                    LabeledContent("Homepage") {
                        Link(homepage, destination: URL(string: homepage)!)
                            .font(.caption)
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    let isInstalled = viewModel.installedPackages.contains { $0.name == package.name }

                    if isInstalled {
                        if package.isOutdated {
                            Button {
                                viewModel.upgrade(package)
                            } label: {
                                Label("Upgrade", systemImage: "arrow.up.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }

                        Button(role: .destructive) {
                            viewModel.uninstall(package)
                        } label: {
                            Label("Uninstall", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            viewModel.install(package)
                        } label: {
                            Label("Install", systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                // MARK: - Release Notes Section
                if isLoadingRelease {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Release Notes", systemImage: "doc.text")
                            .font(.headline)
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading release notes…")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                } else if let release = releaseNote {
                    ReleaseNoteSection(release: release)
                }
            }
            .padding(24)
        }
        .task {
            let service = BrewService()
            detailedPackage = try? await service.getInfo(package.name, type: package.type)

            // Fetch release notes from GitHub
            let homepage = detailedPackage?.homepage ?? package.homepage
            if !homepage.isEmpty {
                isLoadingRelease = true
                releaseNote = await BrewAPIClient.shared.fetchReleaseNotes(homepage: homepage)
                isLoadingRelease = false
            }
        }
    }
}

// MARK: - Reusable Release Notes Section

struct ReleaseNoteSection: View {
    let release: ReleaseNote
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Label("Release Notes", systemImage: "doc.text")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(release.tagName)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.1))
                        .clipShape(Capsule())

                    if !release.publishedAt.isEmpty {
                        Text(release.publishedAt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                // Release title
                if !release.title.isEmpty && release.title != release.tagName {
                    Text(release.title)
                        .font(.subheadline.weight(.semibold))
                }

                // Release body
                Text(release.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                // Link to GitHub
                if let url = URL(string: release.htmlURL), !release.htmlURL.isEmpty {
                    Link(destination: url) {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
            }
        }
        .padding(16)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
