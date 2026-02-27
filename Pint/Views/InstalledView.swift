//
//  InstalledView.swift
//  Pint
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

struct InstalledView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selection = Set<String>()

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            // Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Installed Packages")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("\(viewModel.installedPackages.count) packages installed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Filters
                HStack(spacing: 8) {
                    if !selection.isEmpty {
                        Button(role: .destructive) {
                            let packages = viewModel.installedPackages.filter { selection.contains($0.id) }
                            viewModel.bulkUninstall(packages)
                            selection.removeAll()
                        } label: {
                            Label("Uninstall", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isOperationRunning)

                        Button {
                            let packages = viewModel.installedPackages.filter { selection.contains($0.id) && $0.isOutdated }
                            viewModel.bulkUpgrade(packages)
                            selection.removeAll()
                        } label: {
                            Label("Upgrade", systemImage: "arrow.up.circle")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isOperationRunning || viewModel.installedPackages.filter { selection.contains($0.id) && $0.isOutdated }.isEmpty)

                        Divider().frame(height: 20)
                    }

                    FilterChip(label: "All", isSelected: viewModel.installedFilter == nil) {
                        viewModel.installedFilter = nil
                    }
                    FilterChip(label: "Formulae", isSelected: viewModel.installedFilter == .formula, color: .green) {
                        viewModel.installedFilter = .formula
                    }
                    FilterChip(label: "Casks", isSelected: viewModel.installedFilter == .cask, color: .purple) {
                        viewModel.installedFilter = .cask
                    }
                }
            }
            .padding(24)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Filter packages…", text: $vm.installedSearchText)
                    .textFieldStyle(.plain)
                if !viewModel.installedSearchText.isEmpty {
                    Button {
                        viewModel.installedSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary.opacity(0.5))
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            Divider()

            if viewModel.isLoadingInstalled {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading packages…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if viewModel.filteredInstalled.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 48))
                        .foregroundStyle(.quaternary)
                    Text("No packages found")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List(selection: $selection) {
                    ForEach(viewModel.filteredInstalled) { pkg in
                        InstalledPackageRow(package: pkg)
                            .tag(pkg.id)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(
                    Capsule()
                        .fill(isSelected
                            ? AnyShapeStyle(color.gradient)
                            : AnyShapeStyle(.quaternary)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Installed Package Row

struct InstalledPackageRow: View {
    let package: BrewPackage
    @Environment(AppViewModel.self) private var viewModel
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: package.type == .formula
                                ? [.green.opacity(0.2), .mint.opacity(0.1)]
                                : [.purple.opacity(0.2), .indigo.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: package.type == .formula ? "terminal.fill" : "macwindow")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(package.type == .formula ? .green : .purple)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(package.name)
                        .font(.body.weight(.semibold))
                    if package.isOutdated {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 6) {
                    Text(package.version)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if !package.description.isEmpty {
                        Text("•")
                            .foregroundStyle(.quaternary)
                        Text(package.description)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Hover actions
            if isHovered {
                HStack(spacing: 6) {
                    if package.isOutdated {
                        Button {
                            viewModel.upgrade(package)
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                        .help("Upgrade")
                        .disabled(viewModel.isOperationRunning)
                    }

                    Button(role: .destructive) {
                        viewModel.uninstall(package)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Uninstall")
                    .disabled(viewModel.isOperationRunning)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
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
