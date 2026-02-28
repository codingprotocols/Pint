//
//  SearchView.swift
//  Pint
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

struct SearchView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 16) {
                Text("Search Packages")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )

                    TextField("Search formulae and casks…", text: $vm.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .onSubmit {
                            debounceTask?.cancel()
                            Task { await viewModel.performSearch() }
                        }
                        .onChange(of: vm.searchQuery) { _, newValue in
                            debounceTask?.cancel()
                            guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                                viewModel.searchResults = []
                                return
                            }
                            debounceTask = Task {
                                try? await Task.sleep(for: .milliseconds(300))
                                guard !Task.isCancelled else { return }
                                await viewModel.performSearch()
                            }
                        }

                    if viewModel.isSearching {
                        ProgressView()
                            .controlSize(.small)
                    }

                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.searchQuery = ""
                            viewModel.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .purple.opacity(0.1), radius: 8, y: 4)
                )
            }
            .padding(24)

            Divider()

            if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty && !viewModel.isSearching {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.quaternary)
                    Text("No results for \"\(viewModel.searchQuery)\"")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Try a different search term")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else if viewModel.searchResults.isEmpty {
                PopularSuggestionsView()
            } else {
                List {
                    ForEach(viewModel.searchResults) { pkg in
                        SearchResultRow(package: pkg)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

// MARK: - Popular Suggestions

private struct SuggestionCategory: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let packages: [BrewPackage]
}

struct PopularSuggestionsView: View {
    @Environment(AppViewModel.self) private var viewModel

    private static let categories: [SuggestionCategory] = [
        SuggestionCategory(
            title: "Must-Have Apps",
            icon: "star.fill",
            color: .orange,
            packages: [
                BrewPackage(name: "visual-studio-code", description: "Open-source code editor from Microsoft", type: .cask),
                BrewPackage(name: "iterm2", description: "Terminal emulator as alternative to Apple's Terminal", type: .cask),
                BrewPackage(name: "warp", description: "Rust-based terminal with AI assistance built-in", type: .cask),
                BrewPackage(name: "docker", description: "Platform for containerised application development", type: .cask),
                BrewPackage(name: "postman", description: "Collaboration platform for API development & testing", type: .cask),
                BrewPackage(name: "tableplus", description: "Modern, native database management GUI", type: .cask),
                BrewPackage(name: "sourcetree", description: "Free Git and Mercurial GUI client", type: .cask),
            ]
        ),
        SuggestionCategory(
            title: "CLI Essentials",
            icon: "terminal.fill",
            color: .green,
            packages: [
                BrewPackage(name: "node", description: "JavaScript runtime built on Chrome's V8 engine", type: .formula),
                BrewPackage(name: "gh", description: "GitHub's official command-line tool", type: .formula),
                BrewPackage(name: "wget", description: "Internet file retriever supporting HTTP, HTTPS, FTP", type: .formula),
                BrewPackage(name: "jq", description: "Lightweight and flexible command-line JSON processor", type: .formula),
                BrewPackage(name: "ripgrep", description: "Fast search tool like grep, optimised for code", type: .formula),
                BrewPackage(name: "bat", description: "A cat clone with syntax highlighting and Git integration", type: .formula),
                BrewPackage(name: "fzf", description: "Command-line fuzzy finder for files, history & more", type: .formula),
                BrewPackage(name: "ffmpeg", description: "Play, record, convert, and stream audio and video", type: .formula),
                BrewPackage(name: "htop", description: "Improved interactive process viewer", type: .formula),
            ]
        ),
        SuggestionCategory(
            title: "Productivity",
            icon: "bolt.fill",
            color: .purple,
            packages: [
                BrewPackage(name: "raycast", description: "Supercharged launcher with extensions and AI", type: .cask),
                BrewPackage(name: "rectangle", description: "Move and resize windows with keyboard shortcuts", type: .cask),
                BrewPackage(name: "notion", description: "All-in-one workspace for notes, docs, and tasks", type: .cask),
                BrewPackage(name: "obsidian", description: "Markdown-based knowledge base and note-taking", type: .cask),
                BrewPackage(name: "1password", description: "Password manager and secure digital wallet", type: .cask),
                BrewPackage(name: "slack", description: "Team communication and messaging platform", type: .cask),
                BrewPackage(name: "zoom", description: "Video conferencing and online meetings", type: .cask),
            ]
        ),
        SuggestionCategory(
            title: "Media & Design",
            icon: "paintpalette.fill",
            color: .pink,
            packages: [
                BrewPackage(name: "figma", description: "Collaborative interface design and prototyping tool", type: .cask),
                BrewPackage(name: "vlc", description: "Cross-platform multimedia player for any format", type: .cask),
                BrewPackage(name: "spotify", description: "Music and podcast streaming service", type: .cask),
                BrewPackage(name: "discord", description: "Chat and voice for gaming and communities", type: .cask),
                BrewPackage(name: "handbrake", description: "Open-source video transcoder", type: .cask),
            ]
        ),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Discover Popular Packages")
                            .font(.title3.weight(.semibold))
                        Text("Suggestions based on what developers commonly install")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)

                ForEach(Self.categories) { category in
                    let notInstalled = category.packages.filter { pkg in
                        !viewModel.installedPackages.contains { $0.name == pkg.name }
                    }
                    if !notInstalled.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            // Category header
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(category.color)
                                Text(category.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("· \(notInstalled.count) not installed")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                ForEach(Array(notInstalled.enumerated()), id: \.element.id) { index, pkg in
                                    SearchResultRow(package: pkg)
                                    if index < notInstalled.count - 1 {
                                        Divider().padding(.leading, 56)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.background.secondary)
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let package: BrewPackage
    @Environment(AppViewModel.self) private var viewModel
    @State private var isHovered = false

    private var isInstalled: Bool {
        viewModel.installedPackages.contains { $0.name == package.name }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: package.type == .formula
                                ? [.green.opacity(0.15), .mint.opacity(0.1)]
                                : [.purple.opacity(0.15), .indigo.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: package.type == .formula ? "terminal.fill" : "macwindow")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(package.type == .formula ? .green : .purple)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(package.name)
                        .font(.body.weight(.semibold))
                    TypeBadge(type: package.type)
                    if isInstalled {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                if !package.description.isEmpty {
                    Text(package.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if !package.version.isEmpty {
                Text(package.version)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            if isInstalled {
                Button(role: .destructive) {
                    viewModel.uninstall(package)
                } label: {
                    Label("Uninstall", systemImage: "trash")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isOperationRunning)
            } else {
                Button {
                    viewModel.install(package)
                } label: {
                    Label("Install", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(
                    LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing)
                )
                .disabled(viewModel.isOperationRunning)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? AnyShapeStyle(.quaternary.opacity(0.5)) : AnyShapeStyle(.clear))
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in isHovered = hovering }
    }
}
