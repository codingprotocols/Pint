//
//  SearchView.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

struct SearchView: View {
    @Environment(AppViewModel.self) private var viewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Search Packages")
                    .font(.largeTitle.weight(.bold))

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    TextField("Search Homebrew packages…", text: $vm.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($isSearchFocused)
                        .onSubmit {
                            Task { await viewModel.performSearch() }
                        }

                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.searchQuery = ""
                            viewModel.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        Task { await viewModel.performSearch() }
                    } label: {
                        Text("Search")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(12)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding()

            Divider()

            if viewModel.isSearching {
                Spacer()
                ProgressView("Searching…")
                Spacer()
            } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text("No packages found for \"\(viewModel.searchQuery)\".")
                }
                Spacer()
            } else if viewModel.searchResults.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Search for Homebrew packages")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Type a package name and press Enter or click Search")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                List {
                    Section {
                        ForEach(viewModel.searchResults) { pkg in
                            SearchResultRow(package: pkg)
                        }
                    } header: {
                        Text("\(viewModel.searchResults.count) results")
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(.background)
        .onAppear {
            isSearchFocused = true
        }
    }
}

struct SearchResultRow: View {
    let package: BrewPackage
    @Environment(AppViewModel.self) private var viewModel
    @State private var detailedPackage: BrewPackage?
    @State private var isLoadingDetail: Bool = false

    private var isInstalled: Bool {
        viewModel.installedPackages.contains { $0.name == package.name && $0.type == package.type }
    }

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
                }
                if let detail = detailedPackage, !detail.description.isEmpty {
                    Text(detail.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if isInstalled {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button {
                    viewModel.install(package)
                } label: {
                    Label("Install", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .task {
            guard detailedPackage == nil else { return }
            isLoadingDetail = true
            let service = BrewService()
            if let detail = try? await service.getInfo(package.name, type: package.type) {
                detailedPackage = detail
            }
            isLoadingDetail = false
        }
    }
}
