//
//  SidebarView.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

struct SidebarView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel

        List(selection: $vm.selectedNav) {
            Section("Homebrew") {
                ForEach(NavigationItem.allCases) { item in
                    Label {
                        HStack {
                            Text(item.rawValue)
                            Spacer()
                            if item == .upgrades && !viewModel.outdatedPackages.isEmpty {
                                Text("\(viewModel.outdatedPackages.count)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(.orange.gradient)
                                    )
                            }
                            if item == .installed {
                                Text("\(viewModel.installedPackages.count)")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: item.icon)
                            .foregroundStyle(iconColor(for: item))
                    }
                    .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Divider()
                if !viewModel.brewVersion.isEmpty {
                    Text(viewModel.brewVersion)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func iconColor(for item: NavigationItem) -> Color {
        switch item {
        case .dashboard: return .blue
        case .installed: return .green
        case .upgrades: return .orange
        case .search: return .purple
        case .doctor: return .red
        }
    }
}
