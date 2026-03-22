import SwiftUI

struct SidebarView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var vm = viewModel

        List(selection: $vm.selectedNav) {
            Section {
                ForEach(NavigationItem.allCases) { item in
                    HStack(spacing: 10) {
                        // Icon badge — solid tinted background, adapts to light/dark
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(iconColor(for: item).opacity(colorScheme.iconBgOpacity))
                                .frame(width: 28, height: 28)
                            Image(systemName: item.icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(iconColor(for: item))
                        }

                        Text(item.rawValue)
                            .font(.body)

                        Spacer()

                        // Upgrades badge — uses system accent for urgency
                        if item == .upgrades && !viewModel.outdatedPackages.isEmpty {
                            Text("\(viewModel.outdatedPackages.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange))
                        }

                        // Installed count badge — muted, informational
                        if item == .installed && !viewModel.installedPackages.isEmpty {
                            Text("\(viewModel.installedPackages.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(.controlColor)))
                        }
                    }
                    .padding(.vertical, 2)
                    .tag(item)
                }
            } header: {
                HStack(spacing: 5) {
                    Image(systemName: "mug.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("Pint")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1.0)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 8) {
                    if !viewModel.brewVersion.isEmpty {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text(viewModel.brewVersion)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    SettingsLink {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.controlColor))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    private func iconColor(for item: NavigationItem) -> Color {
        switch item {
        case .dashboard:  return .blue
        case .installed:  return .green
        case .services:   return .teal
        case .taps:       return .orange
        case .quarantine: return .red
        case .history:    return .secondary
        case .upgrades:   return .orange
        case .search:     return .purple
        case .backup:     return .indigo
        case .doctor:     return .pink
        }
    }
}
