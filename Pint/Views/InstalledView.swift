//
//  InstalledView.swift
//  Pint
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

private enum InstalledSortOrder: String, CaseIterable, Identifiable {
    case nameAZ = "Name (A–Z)"
    case nameZA = "Name (Z–A)"
    case outdatedFirst = "Outdated First"
    case formulaeFirst = "Formulae First"
    case casksFirst = "Casks First"
    var id: String { rawValue }
}

struct InstalledView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selection = Set<String>()
    @State private var sortOrder: InstalledSortOrder = .nameAZ
    @State private var groupByType = false
    @State private var selectedPackage: BrewPackage?

    /// Always read from installedPackages so detail reflects live state (pin/unpin, etc.).
    private var liveSelected: BrewPackage? {
        guard let sel = selectedPackage else { return nil }
        return viewModel.installedPackages.first { $0.id == sel.id } ?? sel
    }

    private var sortedInstalled: [BrewPackage] {
        let base = showExplicitOnly
            ? viewModel.filteredInstalled.filter { $0.installedOnRequest }
            : viewModel.filteredInstalled
        switch sortOrder {
        case .nameAZ:        return base
        case .nameZA:        return base.sorted { $0.name > $1.name }
        case .outdatedFirst: return base.sorted { $0.isOutdated && !$1.isOutdated }
        case .formulaeFirst: return base.sorted { $0.type == .formula && $1.type != .formula }
        case .casksFirst:    return base.sorted { $0.type == .cask   && $1.type != .cask }
        }
    }

    @State private var showExplicitOnly = false

    // Derived once per body evaluation — avoids O(n) filter inside a disabled modifier.
    private var hasSelectedOutdated: Bool {
        selection.contains { id in
            viewModel.installedPackages.first { $0.id == id }?.isOutdated == true
        }
    }

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
                        .disabled(viewModel.isOperationRunning || !hasSelectedOutdated)

                        Divider().frame(height: 20)
                    }

                    FilterChip(label: "All", isSelected: viewModel.installedFilter == nil && !showExplicitOnly) {
                        viewModel.installedFilter = nil
                        showExplicitOnly = false
                    }
                    FilterChip(label: "Formulae", isSelected: viewModel.installedFilter == .formula, color: .green) {
                        viewModel.installedFilter = .formula
                        showExplicitOnly = false
                    }
                    FilterChip(label: "Casks", isSelected: viewModel.installedFilter == .cask, color: .purple) {
                        viewModel.installedFilter = .cask
                        showExplicitOnly = false
                    }
                    FilterChip(label: "Explicit", isSelected: showExplicitOnly, color: .blue) {
                        viewModel.installedFilter = nil
                        showExplicitOnly = true
                    }

                    Divider().frame(height: 20)

                    Menu {
                        Section("Sort By") {
                            Picker("Sort", selection: $sortOrder) {
                                ForEach(InstalledSortOrder.allCases) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                            .pickerStyle(.inline)
                        }
                        Divider()
                        Toggle("Group by Type", isOn: $groupByType)
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.callout)
                    }
                    .buttonStyle(.bordered)
                    .help("Sort & Group")
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
                HStack(spacing: 0) {
                    // List pane — narrows when a detail panel is open
                    List(selection: $selection) {
                        if groupByType {
                            // Capture once — sortedInstalled is O(n log n) and must not be called twice.
                            let sorted   = sortedInstalled
                            let formulae = sorted.filter { $0.type == .formula }
                            let casks    = sorted.filter { $0.type == .cask }
                            if !formulae.isEmpty {
                                Section("Formulae (\(formulae.count))") {
                                    ForEach(formulae) { pkg in
                                        InstalledPackageRow(
                                            package: pkg,
                                            onSelect: { selectedPackage = pkg },
                                            isSelected: selectedPackage?.id == pkg.id
                                        ).tag(pkg.id)
                                    }
                                }
                            }
                            if !casks.isEmpty {
                                Section("Casks (\(casks.count))") {
                                    ForEach(casks) { pkg in
                                        InstalledPackageRow(
                                            package: pkg,
                                            onSelect: { selectedPackage = pkg },
                                            isSelected: selectedPackage?.id == pkg.id
                                        ).tag(pkg.id)
                                    }
                                }
                            }
                        } else {
                            ForEach(sortedInstalled) { pkg in
                                InstalledPackageRow(
                                    package: pkg,
                                    onSelect: { selectedPackage = pkg },
                                    isSelected: selectedPackage?.id == pkg.id
                                ).tag(pkg.id)
                            }
                        }
                    }
                    .listStyle(.inset)
                    .frame(maxWidth: liveSelected != nil ? 300 : .infinity)

                    // Detail pane — shown when a package is selected
                    if let pkg = liveSelected {
                        Divider()
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedPackage = nil
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .padding(12)
                            }
                            Divider()
                            PackageDetailView(package: pkg)
                                .id(pkg.name)
                        }
                        .frame(maxWidth: .infinity)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: liveSelected != nil)
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

private let formulaGradient = LinearGradient(
    colors: [.green.opacity(0.2), .mint.opacity(0.1)],
    startPoint: .topLeading, endPoint: .bottomTrailing
)
private let caskGradient = LinearGradient(
    colors: [.purple.opacity(0.2), .indigo.opacity(0.1)],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

struct InstalledPackageRow: View {
    let package: BrewPackage
    var onSelect: (() -> Void)? = nil
    var isSelected: Bool = false
    @Environment(AppViewModel.self) private var viewModel
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(package.type == .formula ? formulaGradient : caskGradient)
                    .frame(width: 36, height: 36)
                Image(systemName: package.type == .formula ? "terminal.fill" : "macwindow")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(package.type == .formula ? .green : .purple)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(package.name)
                        .font(.body.weight(.semibold))
                    if package.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .help("Pinned — will not be upgraded automatically")
                    }
                    if package.isOutdated {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if !package.installedOnRequest {
                        Text("dependency")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.quaternary))
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
                .fill(
                    isSelected
                        ? AnyShapeStyle(Color.accentColor.opacity(0.12))
                        : isHovered ? AnyShapeStyle(.quaternary.opacity(0.5)) : AnyShapeStyle(.clear)
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
        .onHover { hovering in isHovered = hovering }
        .contentShape(Rectangle())
        .onTapGesture { onSelect?() }
    }
}
