//
//  ContentView.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

/// Root view with NavigationSplitView layout.
struct ContentView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel

        NavigationSplitView {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                Group {
                    switch viewModel.selectedNav {
                    case .dashboard:
                        DashboardView()
                    case .installed:
                        InstalledView()
                    case .upgrades:
                        UpgradesView()
                    case .search:
                        SearchView()
                    case .doctor:
                        DoctorView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Inline operation banner at the bottom
                OperationBannerView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            viewModel.loadAll()
        }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .overlay {
            if !viewModel.brewAvailable {
                BrewNotFoundView {
                    viewModel.loadAll()
                }
            }
        }
    }
}

/// Overlay shown when Homebrew is not installed — includes installation instructions.
struct BrewNotFoundView: View {
    var onRetry: () -> Void

    private let installCommand = """
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    """

    @State private var copied = false

    var body: some View {
        ZStack {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Icon
                Image(systemName: "mug.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tertiary)

                // Title
                Text("Homebrew Not Found")
                    .font(.largeTitle.bold())

                Text("TapHouse requires Homebrew to manage packages.\nFollow the steps below to install it.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Instruction card
                VStack(alignment: .leading, spacing: 16) {
                    Label("How to Install", systemImage: "terminal.fill")
                        .font(.headline)

                    // Step 1
                    HStack(alignment: .top, spacing: 10) {
                        Text("1.")
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        Text("Open **Terminal** (press ⌘ + Space, type \"Terminal\", hit Enter)")
                    }
                    .font(.callout)

                    // Step 2 — the command
                    HStack(alignment: .top, spacing: 10) {
                        Text("2.")
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        Text("Paste and run this command:")
                    }
                    .font(.callout)

                    // Command block
                    HStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(installCommand)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(10)
                        }

                        Divider()

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(installCommand, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copied = false
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .frame(width: 36, height: 36)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .help(copied ? "Copied!" : "Copy to clipboard")
                    }
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary, lineWidth: 1)
                    )

                    // Step 3
                    HStack(alignment: .top, spacing: 10) {
                        Text("3.")
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        Text("Follow the on-screen prompts, then click **Retry** below.")
                    }
                    .font(.callout)
                }
                .padding(20)
                .frame(maxWidth: 560, alignment: .leading)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)

                // Actions
                HStack(spacing: 16) {
                    Link(destination: URL(string: "https://brew.sh")!) {
                        Label("brew.sh", systemImage: "safari")
                    }
                    .foregroundStyle(.blue)

                    Button {
                        onRetry()
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(40)
        }
    }
}
