//
//  TapsView.swift
//  Pint
//
//  Created by Antigravity on 26/02/26.
//

import SwiftUI

struct TapsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showAddTap = false
    @State private var newTapName = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Taps")
                        .font(.title2.bold())
                    Text("Add and remove Homebrew repositories (taps)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    if viewModel.isLoadingTaps {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button {
                        showAddTap = true
                    } label: {
                        Label("Add Tap", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isOperationRunning)

                    Button {
                        Task { await viewModel.loadTaps() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("Refresh taps")
                    .disabled(viewModel.isOperationRunning)
                }
            }
            .padding()
            .background(.ultraThinMaterial)

            // Taps List
            if viewModel.taps.isEmpty && !viewModel.isLoadingTaps {
                ContentUnavailableView(
                    "No Custom Taps",
                    systemImage: "spigot",
                    description: Text("You only have the default Homebrew repositories.")
                )
            } else {
                List {
                    ForEach(viewModel.taps, id: \.self) { tap in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tap)
                                    .font(.headline)

                                if tap.starts(with: "homebrew/") {
                                    Text("Official")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }

                            Spacer()

                            Button(role: .destructive) {
                                viewModel.removeTap(tap)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Untap repository")
                            .disabled(viewModel.isOperationRunning)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .sheet(isPresented: $showAddTap) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add New Tap")
                    .font(.headline)

                Text("Enter the name of the repository to tap (e.g., homebrew/cask-fonts).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Repository Name", text: $newTapName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()
                    Button("Cancel") {
                        showAddTap = false
                        newTapName = ""
                    }
                    .buttonStyle(.plain)

                    Button("Add Tap") {
                        viewModel.addTap(newTapName)
                        showAddTap = false
                        newTapName = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTapName.isEmpty || viewModel.isOperationRunning)
                }
            }
            .padding()
            .frame(width: 400)
        }
        .task {
            if viewModel.taps.isEmpty {
                await viewModel.loadTaps()
            }
        }
    }
}
