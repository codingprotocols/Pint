//
//  InstalledView.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

struct InstalledView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedPackage: BrewPackage?

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Installed Packages")
                        .font(.largeTitle.weight(.bold))
                    Text("\(viewModel.installedPackages.count) packages installed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Picker("Type", selection: $vm.installedFilter) {
                    Text("All").tag(nil as PackageType?)
                    Text("Formulae").tag(PackageType.formula as PackageType?)
                    Text("Casks").tag(PackageType.cask as PackageType?)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)

                Button {
                    Task { await viewModel.loadInstalled() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter packages…", text: $vm.installedSearchText)
                    .textFieldStyle(.plain)
                if !viewModel.installedSearchText.isEmpty {
                    Button {
                        viewModel.installedSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            if viewModel.isLoadingInstalled {
                Spacer()
                ProgressView("Loading packages…")
                Spacer()
            } else if viewModel.filteredInstalled.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("No Packages Found", systemImage: "shippingbox")
                } description: {
                    Text("No packages match your current filter.")
                }
                Spacer()
            } else {
                List(viewModel.filteredInstalled, selection: $selectedPackage) { pkg in
                    InstalledPackageRow(package: pkg)
                        .tag(pkg)
                }
                .listStyle(.inset)
            }
        }
        .background(.background)
    }
}

struct InstalledPackageRow: View {
    let package: BrewPackage
    @Environment(AppViewModel.self) private var viewModel
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: package.type == .formula ? "terminal.fill" : "macwindow")
                .font(.title3)
                .foregroundStyle(package.type == .formula ? .green : .purple)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(package.name)
                        .font(.body.weight(.medium))
                    TypeBadge(type: package.type)
                    if package.isOutdated {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
                if !package.description.isEmpty {
                    Text(package.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(package.version)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            if isHovering {
                HStack(spacing: 4) {
                    if package.isOutdated {
                        Button {
                            viewModel.upgrade(package)
                        } label: {
                            Image(systemName: "arrow.up.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.orange)
                    }

                    Button {
                        viewModel.uninstall(package)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
