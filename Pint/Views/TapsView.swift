//
//  TapsView.swift
//  Pint
//
//  Created by Antigravity on 26/02/26.
//

import SwiftUI

struct TapsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var taps: [String] = []
    @State private var isLoading = false
    @State private var showAddTap = false
    @State private var newTapName = ""

    private let brewService = BrewService()

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
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button {
                        showAddTap = true
                    } label: {
                        Label("Add Tap", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { await loadTaps() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("Refresh taps")
                }
            }
            .padding()
            .background(.ultraThinMaterial)

            // Taps List
            if taps.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Custom Taps",
                    systemImage: "spigot",
                    description: Text("You only have the default Homebrew repositories.")
                )
            } else {
                List {
                    ForEach(taps, id: \.self) { tap in
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
                                removeTap(tap)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Untap repository")
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
                        addTap(newTapName)
                        showAddTap = false
                        newTapName = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTapName.isEmpty)
                }
            }
            .padding()
            .frame(width: 400)
        }
        .task {
            await loadTaps()
        }
    }

    private func loadTaps() async {
        isLoading = true
        defer { isLoading = false }
        do {
            taps = try await brewService.listTaps()
        } catch {
            print("Failed to load taps: \(error)")
        }
    }

    private func addTap(_ name: String) {
        let op = BrewOperation(command: "tap", packageName: name)
        runOperation(operation: op) { onOutput in
            try await brewService.addTap(name, onOutput: onOutput)
            await loadTaps()
        }
    }

    private func removeTap(_ name: String) {
        let op = BrewOperation(command: "untap", packageName: name)
        runOperation(operation: op) { onOutput in
            try await brewService.removeTap(name, onOutput: onOutput)
            await loadTaps()
        }
    }

    private func runOperation(operation: BrewOperation, action: @escaping (@escaping @Sendable (String) -> Void) async throws -> Void) {
        // We reuse the app-wide operation runner by calling viewModel's helper
        // But since we can't easily access the private helper, we'll just use a simplified version here
        // or actually, we should probably add these to AppViewModel if they involve operations
        // For now, let's just trigger it via the existing ViewModel mechanism if possible
        // Actually, Taps management is infrequent enough that maybe it should be in AppViewModel?
        // Let's just implement a simple version here for now.
        Task {
            do {
                try await action { _ in }
                await loadTaps()
            } catch {
                print("Operation failed: \(error)")
            }
        }
    }
}
