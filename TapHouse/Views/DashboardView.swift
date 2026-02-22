//
//  DashboardView.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(.largeTitle.weight(.bold))
                        Text("Your Homebrew at a glance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            viewModel.updateBrew()
                        } label: {
                            Label("Update Homebrew", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)

                        if !viewModel.outdatedPackages.isEmpty {
                            Button {
                                viewModel.upgradeAll()
                            } label: {
                                Label("Upgrade All", systemImage: "arrow.up.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }
                }
                .padding(.horizontal)

                // Stats Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        title: "Total Packages",
                        value: "\(viewModel.installedPackages.count)",
                        icon: "shippingbox.fill",
                        color: .blue
                    )
                    StatCard(
                        title: "Formulae",
                        value: "\(viewModel.totalFormulae)",
                        icon: "terminal.fill",
                        color: .green
                    )
                    StatCard(
                        title: "Casks",
                        value: "\(viewModel.totalCasks)",
                        icon: "macwindow",
                        color: .purple
                    )
                    StatCard(
                        title: "Upgrades Available",
                        value: "\(viewModel.outdatedPackages.count)",
                        icon: "arrow.up.circle.fill",
                        color: viewModel.outdatedPackages.isEmpty ? .gray : .orange
                    )
                }
                .padding(.horizontal)

                // Outdated Packages Section
                if !viewModel.outdatedPackages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Packages Ready to Upgrade")
                                .font(.headline)
                            Spacer()
                        }

                        ForEach(viewModel.outdatedPackages) { pkg in
                            OutdatedPackageRow(package: pkg)
                        }
                    }
                    .padding()
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Recent Operations
                if !viewModel.operationHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.secondary)
                            Text("Recent Operations")
                                .font(.headline)
                            Spacer()
                        }

                        ForEach(viewModel.operationHistory.prefix(5)) { op in
                            HStack {
                                Image(systemName: op.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(op.isSuccess ? .green : .red)
                                Text("brew \(op.command)")
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text(op.packageName)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Loading indicator
                if viewModel.isLoadingInstalled || viewModel.isLoadingOutdated {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading packages…")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                Spacer(minLength: 20)
            }
            .padding(.top)
        }
        .background(.background)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color.gradient)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Outdated Package Row

struct OutdatedPackageRow: View {
    let package: BrewPackage
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(package.name)
                        .font(.body.weight(.medium))
                    TypeBadge(type: package.type)
                }
                HStack(spacing: 4) {
                    Text(package.currentVersion ?? package.version)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(package.latestVersion ?? "latest")
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }
            Spacer()
            Button {
                viewModel.upgrade(package)
            } label: {
                Label("Upgrade", systemImage: "arrow.up.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Type Badge

struct TypeBadge: View {
    let type: PackageType

    var body: some View {
        Text(type == .formula ? "formula" : "cask")
            .font(.caption2.weight(.medium))
            .foregroundStyle(type == .formula ? .green : .purple)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(type == .formula ? .green.opacity(0.15) : .purple.opacity(0.15))
            )
    }
}
