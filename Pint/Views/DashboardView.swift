//
//  DashboardView.swift
//  Pint
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
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dashboard")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Your Homebrew at a glance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            viewModel.updateBrew()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Update")
                            }
                            .font(.callout.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                        .disabled(viewModel.isOperationRunning)

                        if !viewModel.outdatedPackages.isEmpty {
                            Button {
                                viewModel.upgradeAll()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.circle.fill")
                                    Text("Upgrade All")
                                }
                                .font(.callout.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(viewModel.isOperationRunning)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Stats Cards
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    GradientStatCard(
                        title: "Total",
                        value: "\(viewModel.installedPackages.count)",
                        icon: "shippingbox.fill",
                        gradient: [Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.7, blue: 1.0)]
                    )
                    GradientStatCard(
                        title: "Formulae",
                        value: "\(viewModel.totalFormulae)",
                        icon: "terminal.fill",
                        gradient: [Color(red: 0.2, green: 0.8, blue: 0.5), Color(red: 0.4, green: 0.9, blue: 0.7)]
                    )
                    GradientStatCard(
                        title: "Casks",
                        value: "\(viewModel.totalCasks)",
                        icon: "macwindow",
                        gradient: [Color(red: 0.6, green: 0.3, blue: 0.9), Color(red: 0.8, green: 0.5, blue: 1.0)]
                    )
                    GradientStatCard(
                        title: "Upgrades",
                        value: "\(viewModel.outdatedPackages.count)",
                        icon: "arrow.up.circle.fill",
                        gradient: viewModel.outdatedPackages.isEmpty
                            ? [.gray.opacity(0.5), .gray.opacity(0.3)]
                            : [Color(red: 1.0, green: 0.5, blue: 0.1), Color(red: 1.0, green: 0.7, blue: 0.2)]
                    )
                }
                .padding(.horizontal, 24)

                // Outdated Packages Section
                if !viewModel.outdatedPackages.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title3)
                                .foregroundStyle(
                                    LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                                )
                            Text("Packages Ready to Upgrade")
                                .font(.headline)
                            Spacer()
                            Text("\(viewModel.outdatedPackages.count)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(.orange.gradient))
                        }

                        ForEach(viewModel.outdatedPackages) { pkg in
                            OutdatedPackageRow(package: pkg)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                    )
                    .padding(.horizontal, 24)
                }

                // Recent Operations
                if !viewModel.operationHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.blue.gradient)
                            Text("Recent Operations")
                                .font(.headline)
                            Spacer()
                        }

                        ForEach(viewModel.operationHistory.prefix(5)) { op in
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(op.isSuccess
                                            ? LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            : LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                        .frame(width: 24, height: 24)
                                    Image(systemName: op.isSuccess ? "checkmark" : "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }

                                Text("brew \(op.command)")
                                    .font(.system(.callout, design: .monospaced))
                                Spacer()
                                Text(op.packageName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(.quaternary))
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                    )
                    .padding(.horizontal, 24)
                }

                // Loading indicator
                if viewModel.isLoadingInstalled || viewModel.isLoadingOutdated {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading packages…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }

                Spacer(minLength: 20)
            }
            .padding(.top, 20)
        }
    }
}

// MARK: - Gradient Stat Card

struct GradientStatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
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
                HStack(spacing: 8) {
                    Text(package.name)
                        .font(.body.weight(.semibold))
                    TypeBadge(type: package.type)
                }
                HStack(spacing: 6) {
                    Text(package.currentVersion ?? package.version)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.red.opacity(0.12)))
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(package.latestVersion ?? "latest")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.green.opacity(0.12)))
                }
            }
            Spacer()
            Button {
                viewModel.upgrade(package)
            } label: {
                Label("Upgrade", systemImage: "arrow.up.circle")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.orange)
            .opacity(isHovered ? 1 : 0.7)
            .disabled(viewModel.isOperationRunning)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Type Badge

struct TypeBadge: View {
    let type: PackageType

    var body: some View {
        Text(type == .formula ? "formula" : "cask")
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(type == .formula ? .green : .purple)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(type == .formula ? .green.opacity(0.12) : .purple.opacity(0.12))
            )
    }
}
