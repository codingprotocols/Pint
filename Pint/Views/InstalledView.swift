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

    private var liveSelected: BrewPackage? {
        guard let sel = selectedPackage else { return nil }
        return viewModel.installedPackages.first { $0.id == sel.id } ?? sel
    }

    @State private var showExplicitOnly = false

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

    private var hasSelectedOutdated: Bool {
        selection.contains { id in
            viewModel.installedPackages.first { $0.id == id }?.isOutdated == true
        }
    }

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {

            // MARK: Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Installed")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("\(viewModel.installedPackages.count) packages installed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    if !selection.isEmpty {
                        Button(role: .destructive) {
                            let packages = viewModel.installedPackages.filter { selection.contains($0.id) }
                            viewModel.bulkUninstall(packages)
                            selection.removeAll()
                        } label: {
                            Label("Uninstall (\(selection.count))", systemImage: "trash")
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

                    FilterChip(label: "All",      isSelected: viewModel.installedFilter == nil && !showExplicitOnly) {
                        viewModel.installedFilter = nil; showExplicitOnly = false
                    }
                    FilterChip(label: "Formulae", isSelected: viewModel.installedFilter == .formula, color: .green) {
                        viewModel.installedFilter = .formula; showExplicitOnly = false
                    }
                    FilterChip(label: "Casks",    isSelected: viewModel.installedFilter == .cask, color: .purple) {
                        viewModel.installedFilter = .cask; showExplicitOnly = false
                    }
                    FilterChip(label: "Explicit", isSelected: showExplicitOnly, color: .blue) {
                        viewModel.installedFilter = nil; showExplicitOnly = true
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
                .font(.callout)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // MARK: Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Filter packages…", text: $vm.installedSearchText)
                    .textFieldStyle(.plain)
                if !viewModel.installedSearchText.isEmpty {
                    Button { viewModel.installedSearchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separatorColor), lineWidth: 0.5))
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            Divider()

            // MARK: Content
            if viewModel.isLoadingInstalled {
                Spacer()
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Loading packages…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if viewModel.filteredInstalled.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 44))
                        .foregroundStyle(.tertiary)
                    Text("No packages found")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                HStack(spacing: 0) {
                    List(selection: $selection) {
                        if groupByType {
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

                    if let pkg = liveSelected {
                        Divider()
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation(.easeOut(duration: 0.18)) { selectedPackage = nil }
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
                .animation(.easeOut(duration: 0.18), value: liveSelected != nil)
            }
        }
    }
}

// MARK: - Installed Package Row

struct InstalledPackageRow: View {
    let package: BrewPackage
    var onSelect: (() -> Void)? = nil
    var isSelected: Bool = false
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(colorScheme.iconBgOpacity))
                    .frame(width: 32, height: 32)
                Image(systemName: package.type == .formula ? "terminal.fill" : "macwindow")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(package.name)
                        .font(.callout.weight(.semibold))
                    if package.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .help("Pinned — won't be upgraded automatically")
                    }
                    if package.isOutdated {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if !package.installedOnRequest {
                        Text("dep")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color(.controlColor)))
                    }
                }
                HStack(spacing: 5) {
                    Text(package.version)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if !package.description.isEmpty {
                        Text("·").foregroundStyle(.quaternary)
                        Text(package.description)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 4) {
                    if package.isOutdated {
                        Button { viewModel.upgrade(package) } label: {
                            Image(systemName: "arrow.up.circle.fill").foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                        .help("Upgrade")
                        .disabled(viewModel.isOperationRunning)
                    }
                    Button(role: .destructive) { viewModel.uninstall(package) } label: {
                        Image(systemName: "trash").foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Uninstall")
                    .disabled(viewModel.isOperationRunning)
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowBackground)
        )
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .animation(.easeOut(duration: 0.1), value: isSelected)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onSelect?() }
    }

    private var iconColor: Color {
        package.type == .formula ? .green : .purple
    }

    private var rowBackground: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(Color.accentColor.opacity(0.1)) }
        if isHovered  { return AnyShapeStyle(Color(.controlColor).opacity(0.6)) }
        return AnyShapeStyle(.clear)
    }
}
