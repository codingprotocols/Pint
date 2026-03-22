import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: Header + Actions
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(.system(.title, design: .rounded, weight: .bold))
                        Text("Homebrew at a glance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button { viewModel.updateBrew() } label: {
                            Label("Update", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isOperationRunning)

                        Button { viewModel.autoRemove() } label: {
                            Label("Autoremove", systemImage: "trash.slash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isOperationRunning)
                        .help("Remove dependencies no longer needed")

                        Button { viewModel.cleanupCache() } label: {
                            Label("Cleanup", systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isOperationRunning)
                        .help("Remove old versions and cached downloads")

                        if !viewModel.outdatedPackages.isEmpty {
                            Button { viewModel.upgradeAll() } label: {
                                Label("Upgrade All", systemImage: "arrow.up.circle.fill")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(viewModel.isOperationRunning)
                        }
                    }
                    .font(.callout)
                }
                .padding(.horizontal, 24)

                // MARK: Stat Cards
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    StatCard(title: "Total",    value: "\(viewModel.installedPackages.count)", icon: "shippingbox.fill", color: .blue) {
                        viewModel.selectedNav = .installed; viewModel.installedFilter = nil
                    }
                    StatCard(title: "Formulae", value: "\(viewModel.totalFormulae)",           icon: "terminal.fill",     color: .green) {
                        viewModel.selectedNav = .installed; viewModel.installedFilter = .formula
                    }
                    StatCard(title: "Casks",    value: "\(viewModel.totalCasks)",              icon: "macwindow",         color: .purple) {
                        viewModel.selectedNav = .installed; viewModel.installedFilter = .cask
                    }
                    StatCard(
                        title: "Upgrades",
                        value: "\(viewModel.outdatedPackages.count)",
                        icon: "arrow.up.circle.fill",
                        color: viewModel.outdatedPackages.isEmpty ? .secondary : .orange
                    ) { viewModel.selectedNav = .upgrades }
                }
                .padding(.horizontal, 24)

                // MARK: Stale database warning
                if viewModel.isBrewUpdateStale {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Formula database may be outdated")
                                .font(.callout.weight(.medium))
                            Text(viewModel.lastBrewUpdateDate.map {
                                "Last updated \(RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date()))"
                            } ?? "Never updated")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { viewModel.updateBrew() } label: {
                            Label("Update Now", systemImage: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                        .controlSize(.small)
                        .disabled(viewModel.isOperationRunning)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.yellow.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.yellow.opacity(0.2), lineWidth: 0.5))
                    )
                    .padding(.horizontal, 24)
                }

                // MARK: Outdated packages
                if !viewModel.outdatedPackages.isEmpty {
                    SectionCardWithBadge(icon: "arrow.up.circle.fill", iconColor: .orange, title: "Ready to Upgrade") {
                        Text("\(viewModel.outdatedPackages.count)")
                    } content: {
                        VStack(spacing: 0) {
                            ForEach(viewModel.outdatedPackages) { pkg in
                                OutdatedPackageRow(package: pkg)
                                if pkg.id != viewModel.outdatedPackages.last?.id {
                                    Divider().padding(.leading, 12)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // MARK: Recent operations
                if !viewModel.operationHistory.isEmpty {
                    SectionCard(icon: "clock", iconColor: .blue, title: "Recent Operations") {
                        VStack(spacing: 0) {
                            ForEach(viewModel.operationHistory.prefix(5)) { op in
                                HStack(spacing: 10) {
                                    Image(systemName: op.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(op.isSuccess ? .green : .red)
                                        .font(.system(size: 15))
                                    Text("brew \(op.command)")
                                        .font(.system(.callout, design: .monospaced))
                                    Spacer()
                                    Text(op.packageName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color(.controlColor)))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                if op.id != viewModel.operationHistory.prefix(5).last?.id {
                                    Divider().padding(.leading, 40)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // MARK: Loading
                if viewModel.isLoadingInstalled || viewModel.isLoadingOutdated {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading packages…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                }

                Spacer(minLength: 20)
            }
            .padding(.top, 24)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var action: (() -> Void)? = nil

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button { action?() } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color.opacity(colorScheme.iconBgOpacity))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(color)
                    }
                    Spacer()
                    if action != nil {
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .opacity(isHovered ? 1 : 0)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .cardStyle()
            .opacity(isHovered ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Outdated Package Row

struct OutdatedPackageRow: View {
    let package: BrewPackage
    @Environment(AppViewModel.self) private var viewModel
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(package.name)
                        .font(.callout.weight(.semibold))
                    TypeBadge(type: package.type)
                }
                HStack(spacing: 6) {
                    Text(package.currentVersion ?? package.version)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color(.controlColor)))
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(package.latestVersion ?? "latest")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.green.opacity(0.1)))
                }
            }
            Spacer()
            Button { viewModel.upgrade(package) } label: {
                Label("Upgrade", systemImage: "arrow.up.circle")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.orange)
            .disabled(viewModel.isOperationRunning)
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(isHovered ? Color(.controlColor).opacity(0.5) : .clear)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

