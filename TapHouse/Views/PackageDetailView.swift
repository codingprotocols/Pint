//
//  PackageDetailView.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

struct PackageDetailView: View {
    let package: BrewPackage
    @Environment(AppViewModel.self) private var viewModel
    @State private var detailedPackage: BrewPackage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(package.type == .formula ? .green.opacity(0.15) : .purple.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: package.type == .formula ? "terminal.fill" : "macwindow")
                            .font(.title)
                            .foregroundStyle(package.type == .formula ? .green : .purple)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(package.name)
                                .font(.title.weight(.bold))
                            TypeBadge(type: package.type)
                        }
                        if let detail = detailedPackage {
                            Text(detail.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                LabeledContent("Version") {
                    Text(detailedPackage?.version ?? package.version)
                        .font(.system(.body, design: .monospaced))
                }

                if let homepage = detailedPackage?.homepage, !homepage.isEmpty {
                    LabeledContent("Homepage") {
                        Link(homepage, destination: URL(string: homepage)!)
                            .font(.caption)
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    let isInstalled = viewModel.installedPackages.contains { $0.name == package.name }

                    if isInstalled {
                        if package.isOutdated {
                            Button {
                                viewModel.upgrade(package)
                            } label: {
                                Label("Upgrade", systemImage: "arrow.up.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }

                        Button(role: .destructive) {
                            viewModel.uninstall(package)
                        } label: {
                            Label("Uninstall", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            viewModel.install(package)
                        } label: {
                            Label("Install", systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(24)
        }
        .task {
            let service = BrewService()
            detailedPackage = try? await service.getInfo(package.name, type: package.type)
        }
    }
}
