//
//  ServicesView.swift
//  Pint
//
//  Created by Antigravity on 26/02/26.
//

import SwiftUI

struct ServicesView: View {
    @State private var viewModel = ServicesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Services")
                        .font(.title2.bold())
                    Text("Manage and monitor your Homebrew services")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button {
                        Task { await viewModel.loadServices() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("Refresh services")

                    Menu {
                        Section("Auto-Refresh") {
                            Toggle("Enabled", isOn: Binding(
                                get: { viewModel.isAutoRefreshEnabled },
                                set: { _ in viewModel.toggleAutoRefresh() }
                            ))

                            Picker("Interval", selection: $viewModel.refreshInterval) {
                                Text("10s").tag(10)
                                Text("30s").tag(30)
                                Text("1m").tag(60)
                                Text("5m").tag(300)
                            }
                            .onChange(of: viewModel.refreshInterval) {
                                viewModel.startAutoRefresh()
                            }
                        }
                    } label: {
                        Image(systemName: "timer")
                        Text("\(viewModel.refreshInterval)s")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(.ultraThinMaterial)

            // Services List
            if viewModel.services.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Services",
                    systemImage: "square.stack.3d.up.slash",
                    description: Text("You don't have any Homebrew services installed or running.")
                )
            } else {
                List {
                    ForEach(viewModel.services) { service in
                        ServiceRow(service: service, viewModel: viewModel)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .task {
            await viewModel.loadServices()
        }
    }
}

struct ServiceRow: View {
    let service: BrewServiceItem
    let viewModel: ServicesViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Status Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(service.status.color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: service.status.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(service.status.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(service.status.rawValue.capitalized)
                        .font(.caption.bold())
                        .foregroundStyle(service.status.color)

                    if let user = service.user {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(user)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                if service.status == .started {
                    Button {
                        Task { await viewModel.restartService(service.name) }
                    } label: {
                        Label("Restart", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await viewModel.stopService(service.name) }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button {
                        Task { await viewModel.startService(service.name) }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            .controlSize(.small)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ServicesView()
}
