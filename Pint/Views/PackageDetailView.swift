//
//  PackageDetailView.swift
//  Pint
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
    @State private var showDependencyTree = false
    @State private var dependencyTree = ""
    @State private var isLoadingTree = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero header
                HStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: package.type == .formula
                                        ? [.green.opacity(0.2), .mint.opacity(0.1)]
                                        : [.purple.opacity(0.2), .indigo.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                        Image(systemName: package.type == .formula ? "terminal.fill" : "macwindow")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: package.type == .formula ? [.green, .mint] : [.purple, .indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Text(package.name)
                                .font(.system(.title, design: .rounded, weight: .bold))
                            
                            Button {
                                viewModel.toggleFavorite(package)
                            } label: {
                                Image(systemName: package.isFavorite ? "heart.fill" : "heart")
                                    .foregroundStyle(package.isFavorite ? .red : .secondary)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            .help(package.isFavorite ? "Remove from favorites" : "Add to favorites")

                            TypeBadge(type: package.type)
                        }
                        if let detail = detailedPackage {
                            Text(detail.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Info cards
                HStack(spacing: 14) {
                    InfoCard(
                        title: "Version",
                        value: detailedPackage?.version ?? package.version,
                        icon: "tag.fill",
                        color: .blue
                    )

                    if let homepage = detailedPackage?.homepage, !homepage.isEmpty {
                        InfoCard(
                            title: "Homepage",
                            value: URL(string: homepage)?.host ?? homepage,
                            icon: "globe",
                            color: .cyan,
                            link: homepage
                        )
                    }

                    // Show install origin — only meaningful for formulae
                    if package.type == .formula {
                        if !package.installedOnRequest {
                            InfoCard(
                                title: "Installed As",
                                value: "Dependency",
                                icon: "arrow.triangle.branch",
                                color: .secondary
                            )
                        }
                        if package.isPinned {
                            InfoCard(
                                title: "Status",
                                value: "Pinned",
                                icon: "pin.fill",
                                color: .blue
                            )
                        }
                    }
                }

                Divider()

                // Actions
                HStack(spacing: 12) {
                    let isInstalled = viewModel.installedPackages.contains { $0.name == package.name }

                    if isInstalled {
                        if package.isOutdated {
                            Button {
                                viewModel.upgrade(package)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.circle.fill")
                                    Text("Upgrade")
                                }
                                .font(.callout.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(viewModel.isOperationRunning)
                        }

                        Button(role: .destructive) {
                            viewModel.uninstall(package)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("Uninstall")
                            }
                            .font(.callout.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isOperationRunning)

                        // Dependency Tree Button
                        if package.type == .formula {
                            Button {
                                showDependencyTree = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "tree.circle.fill")
                                    Text("Dependency Tree")
                                }
                                .font(.callout.weight(.medium))
                            }
                            .buttonStyle(.bordered)

                            // Pin / Unpin — formulae only; casks do not support pinning
                            let livePackage = viewModel.installedPackages.first { $0.id == package.id } ?? package
                            Button {
                                if livePackage.isPinned {
                                    viewModel.unpin(livePackage)
                                } else {
                                    viewModel.pin(livePackage)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: livePackage.isPinned ? "pin.slash" : "pin.fill")
                                    Text(livePackage.isPinned ? "Unpin" : "Pin")
                                }
                                .font(.callout.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .tint(livePackage.isPinned ? .secondary : .blue)
                            .help(livePackage.isPinned
                                  ? "Allow upgrades for this formula"
                                  : "Prevent this formula from being upgraded")
                        }
                    } else {
                        Button {
                            viewModel.install(package)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Install")
                            }
                            .font(.callout.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(
                            LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing)
                        )
                        .disabled(viewModel.isOperationRunning)
                    }
                }

                // Release Notes Section
                if isLoadingRelease {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.blue.gradient)
                            Text("Release Notes")
                                .font(.headline)
                        }
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading release notes…")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.controlBackgroundColor))
                    )
                } else if let release = releaseNote {
                    ReleaseNoteSection(release: release)
                }

                // Caveats Section — post-install warnings printed by brew
                if let caveats = detailedPackage?.caveats ?? package.caveats, !caveats.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Caveats", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)

                        Text(caveats)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.orange.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.orange.opacity(0.2), lineWidth: 1))
                    )
                }

                Divider()

                // Notes Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("My Notes", systemImage: "pencil.and.outline")
                            .font(.headline)
                        Spacer()
                    }

                    TextEditor(text: Binding(
                        get: { package.notes },
                        set: { viewModel.updateNotes(package, notes: $0) }
                    ))
                    .font(.body)
                    .padding(8)
                    .frame(minHeight: 100)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                }
            }
            .padding(28)
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
        .sheet(isPresented: $showDependencyTree) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Dependency Tree for \(package.name)")
                        .font(.headline)
                    Spacer()
                    Button("Close") {
                        showDependencyTree = false
                    }
                    .buttonStyle(.plain)
                }

                if isLoadingTree {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView("Loading tree...")
                        Spacer()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        Text(dependencyTree)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding()
            .frame(width: 500, height: 400)
            .onAppear {
                fetchTree()
            }
        }
    }

    private func fetchTree() {
        isLoadingTree = true
        Task {
            let service = BrewService()
            dependencyTree = (try? await service.getDependencyTree(package.name)) ?? "Failed to load dependency tree."
            isLoadingTree = false
        }
    }
}

// MARK: - Info Card

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var link: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let link, let url = URL(string: link) {
                Link(value, destination: url)
                    .font(.system(.callout, design: .monospaced, weight: .medium))
            } else {
                Text(value)
                    .font(.system(.callout, design: .monospaced, weight: .medium))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
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
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.blue.gradient)
                    Text("Release Notes")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(release.tagName)
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.blue)
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if !release.title.isEmpty && release.title != release.tagName {
                    Text(release.title)
                        .font(.subheadline.weight(.semibold))
                }

                Text(release.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                if let url = URL(string: release.htmlURL), !release.htmlURL.isEmpty {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text("View on GitHub")
                        }
                        .font(.caption.weight(.medium))
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(colors: [.blue.opacity(0.2), .cyan.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }
}
