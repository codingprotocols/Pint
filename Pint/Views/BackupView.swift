//
//  BackupView.swift
//  Pint
//
//  Created by Ajeet Yadav on 23/02/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(AppViewModel.self) private var viewModel
    @StateObject private var backupManager = BackupManager()
    @State private var importedPackages: [BackupManager.PackageEntry] = []
    @State private var selectedForImport: Set<String> = []
    @State private var showImportPreview = false
    @State private var isImporting = false
    @State private var exportSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Backup & Restore")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Export and import your package list")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                // Export Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 28, height: 28)
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Text("Export Packages")
                            .font(.headline)
                        Spacer()
                        Text("\(viewModel.installedPackages.count) packages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.quaternary))
                    }

                    Text("Save your installed packages as a portable file to restore later or share across machines.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button {
                            exportAsJSON()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.fill")
                                Text("Export as JSON")
                            }
                            .font(.callout.weight(.medium))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(
                            LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing)
                        )

                        Button {
                            exportAsBrewfile()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "terminal.fill")
                                Text("Export as Brewfile")
                            }
                            .font(.callout.weight(.medium))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                    }

                    if exportSuccess {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Exported successfully!")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.green)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                )
                .padding(.horizontal, 24)

                // Import Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 28, height: 28)
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Text("Import Packages")
                            .font(.headline)
                    }

                    Text("Restore packages from a Pint JSON backup or a Brewfile.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Button {
                        importFromFile()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                            Text("Choose Backup File…")
                        }
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(
                        LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                    )

                    // Import preview
                    if showImportPreview && !importedPackages.isEmpty {
                        ImportPreviewSection(
                            packages: importedPackages,
                            installedNames: Set(viewModel.installedPackages.map(\.name)),
                            selectedForImport: $selectedForImport,
                            isImporting: $isImporting,
                            onInstall: installSelected
                        )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                )
                .padding(.horizontal, 24)

                Spacer(minLength: 20)
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Export Actions

    private func exportAsJSON() {
        guard let data = backupManager.exportJSON(packages: viewModel.installedPackages) else { return }

        let panel = NSSavePanel()
        panel.title = "Export Pint Backup"
        panel.nameFieldStringValue = "PintBackup.json"
        panel.allowedContentTypes = [.json]

        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
            showExportSuccess()
        }
    }

    private func exportAsBrewfile() {
        let content = backupManager.exportBrewfile(packages: viewModel.installedPackages)

        let panel = NSSavePanel()
        panel.title = "Export Brewfile"
        panel.nameFieldStringValue = "Brewfile"
        panel.allowedContentTypes = [.plainText]

        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
            showExportSuccess()
        }
    }

    private func showExportSuccess() {
        withAnimation { exportSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { exportSuccess = false }
        }
    }

    // MARK: - Import Actions

    private func importFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Package List"
        panel.allowedContentTypes = [.json, .plainText]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url) {
                // Try JSON first
                if let entries = backupManager.importJSON(data: data) {
                    importedPackages = entries
                } else if let content = String(data: data, encoding: .utf8) {
                    // Try Brewfile
                    importedPackages = backupManager.importBrewfile(content: content)
                }

                if !importedPackages.isEmpty {
                    // Pre-select packages that aren't already installed
                    let installedNames = Set(viewModel.installedPackages.map(\.name))
                    selectedForImport = Set(importedPackages.filter { !installedNames.contains($0.name) }.map(\.id))
                    withAnimation { showImportPreview = true }
                }
            }
        }
    }

    private func installSelected() {
        let toInstall = importedPackages.filter { selectedForImport.contains($0.id) }
        guard !toInstall.isEmpty else { return }

        isImporting = true
        Task {
            for entry in toInstall {
                let pkg = BrewPackage(
                    name: entry.name,
                    type: entry.type == "cask" ? .cask : .formula
                )
                viewModel.install(pkg)
                // Small delay between installs to not overwhelm
                try? await Task.sleep(for: .milliseconds(500))
            }
            await MainActor.run {
                isImporting = false
                withAnimation { showImportPreview = false }
            }
        }
    }
}

// MARK: - Import Preview Section

struct ImportPreviewSection: View {
    let packages: [BackupManager.PackageEntry]
    let installedNames: Set<String>
    @Binding var selectedForImport: Set<String>
    @Binding var isImporting: Bool
    let onInstall: () -> Void

    private var newPackages: [BackupManager.PackageEntry] {
        packages.filter { !installedNames.contains($0.name) }
    }

    private var existingPackages: [BackupManager.PackageEntry] {
        packages.filter { installedNames.contains($0.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                Text("\(packages.count) packages found")
                    .font(.callout.weight(.medium))
                Spacer()
                if !newPackages.isEmpty {
                    Text("\(newPackages.count) new")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.green.gradient))
                }
                if !existingPackages.isEmpty {
                    Text("\(existingPackages.count) already installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Package list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(packages) { entry in
                        let isInstalled = installedNames.contains(entry.name)
                        let isSelected = selectedForImport.contains(entry.id)

                        HStack(spacing: 10) {
                            Button {
                                if isSelected {
                                    selectedForImport.remove(entry.id)
                                } else {
                                    selectedForImport.insert(entry.id)
                                }
                            } label: {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected ? .green : .gray)
                            }
                            .buttonStyle(.plain)
                            .disabled(isInstalled)

                            Image(systemName: entry.type == "formula" ? "terminal.fill" : "macwindow")
                                .font(.caption)
                                .foregroundStyle(entry.type == "formula" ? .green : .purple)

                            Text(entry.name)
                                .font(.callout.weight(.medium))

                            if isInstalled {
                                Text("installed")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(.green.opacity(0.1)))
                            }

                            Spacer()

                            if !entry.version.isEmpty {
                                Text(entry.version)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .opacity(isInstalled ? 0.5 : 1.0)
                    }
                }
            }
            .frame(maxHeight: 250)

            // Install button
            HStack {
                Button {
                    if selectedForImport.count == newPackages.count {
                        selectedForImport.removeAll()
                    } else {
                        selectedForImport = Set(newPackages.map(\.id))
                    }
                } label: {
                    Text(selectedForImport.count == newPackages.count ? "Deselect All" : "Select All New")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                    Text("Installing…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        onInstall()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Install \(selectedForImport.count) Packages")
                        }
                        .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(selectedForImport.isEmpty)
                }
            }
        }
    }
}
