//
//  SearchView.swift
//  Pint
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

struct SearchView: View {
    @Environment(AppViewModel.self) private var viewModel

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
                            Task { await viewModel.performSearch() }
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
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple.opacity(0.3), .indigo.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("Search Homebrew packages")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Find formulae and casks to install")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
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
