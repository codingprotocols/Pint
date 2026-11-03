//
//  DoctorView.swift
//  Pint
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

struct DoctorView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Brew Doctor")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Diagnose your Homebrew installation")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button {
                    Task { await viewModel.loadDoctor() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stethoscope")
                        Text("Run Diagnostics")
                    }
                    .font(.callout.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(
                    LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
                )
            }
            .padding(24)

            Divider()

            // Reclaim space — surfaces the safe-to-remove categories (cache,
            // unused dependencies) with a one-line reason each, before any
            // destructive action is taken.
            ReclaimSpacePanel()
                .padding(.horizontal, 24)
                .padding(.top, 24)

            if viewModel.isLoadingDoctor {
                Spacer()
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [.red.opacity(0.1), .pink.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 80, height: 80)
                        ProgressView()
                            .controlSize(.large)
                    }
                    Text("Running brew doctor…")
                        .font(.headline)
                    Text("This may take a moment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if viewModel.doctorOutput.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [.red.opacity(0.08), .pink.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 80, height: 80)
                        Image(systemName: "stethoscope")
                            .font(.system(size: 36))
                            .foregroundStyle(
                                LinearGradient(colors: [.red.opacity(0.4), .pink.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                    Text("No diagnostics yet")
                        .font(.title2.weight(.semibold))
                    Text("Click \"Run Diagnostics\" to check your Homebrew installation.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(parseDoctorOutput(), id: \.self) { section in
                            DoctorSection(section: section)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear {
            if viewModel.doctorOutput.isEmpty {
                Task { await viewModel.loadDoctor() }
            }
            if viewModel.diskUsage.isEmpty {
                Task { await viewModel.loadDiskUsage() }
            }
            Task { await viewModel.loadReclaimPreview() }
        }
    }

    private func parseDoctorOutput() -> [DoctorOutputSection] {
        let lines = viewModel.doctorOutput.components(separatedBy: "\n")
        var sections: [DoctorOutputSection] = []
        var currentType: DoctorOutputSection.SectionType = .info
        var currentLines: [String] = []

        let hasContent = { (ls: [String]) in
            ls.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        for line in lines {
            if line.hasPrefix("Warning:") || line.hasPrefix("Error:") {
                if hasContent(currentLines) {
                    sections.append(DoctorOutputSection(type: currentType, lines: currentLines))
                }
                currentType = line.hasPrefix("Warning:") ? .warning : .error
                currentLines = [line]
            } else if line.contains("Your system is ready to brew.") {
                if hasContent(currentLines) {
                    sections.append(DoctorOutputSection(type: currentType, lines: currentLines))
                }
                sections.append(DoctorOutputSection(type: .success, lines: [line]))
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }

        if hasContent(currentLines) {
            sections.append(DoctorOutputSection(type: currentType, lines: currentLines))
        }

        return sections
    }
}

// MARK: - Reclaim Space

/// Shedi-inspired panel: shows the safe-to-remove categories side by side,
/// each with how much it holds and a one-line reason it's safe to clear, so a
/// user can reclaim disk space without guessing what brew is about to delete.
struct ReclaimSpacePanel: View {
    @Environment(AppViewModel.self) private var viewModel

    private var cacheAmount: String {
        if !viewModel.reclaimableCacheSpace.isEmpty { return viewModel.reclaimableCacheSpace }
        if !viewModel.diskUsage.isEmpty, viewModel.diskUsage.first != "E" {
            return String(viewModel.diskUsage.split(separator: "\t").first ?? "—")
        }
        return "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("Reclaim space", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                if viewModel.isLoadingReclaimPreview {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await viewModel.loadReclaimPreview() }
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack(spacing: 16) {
                ReclaimCategoryCard(
                    icon: "archivebox",
                    tint: .blue,
                    title: "Download cache",
                    amount: cacheAmount,
                    reason: "Old downloads and package versions — brew re-fetches them whenever it needs them again.",
                    actionTitle: "Clean cache",
                    isEnabled: !viewModel.isOperationRunning
                ) {
                    viewModel.cleanupCache()
                }

                ReclaimCategoryCard(
                    icon: "shippingbox",
                    tint: .orange,
                    title: "Unused dependencies",
                    amount: viewModel.orphanedDependencies.isEmpty ? "None" : "\(viewModel.orphanedDependencies.count)",
                    reason: viewModel.orphanedDependencies.isEmpty
                        ? "Nothing to remove — every installed dependency is still needed by something."
                        : "Installed only as dependencies and no longer required: \(viewModel.orphanedDependencies.prefix(6).joined(separator: ", "))\(viewModel.orphanedDependencies.count > 6 ? "…" : "").",
                    actionTitle: viewModel.orphanedDependencies.isEmpty ? "Nothing to remove" : "Remove \(viewModel.orphanedDependencies.count)",
                    isEnabled: !viewModel.isOperationRunning && !viewModel.orphanedDependencies.isEmpty
                ) {
                    viewModel.autoRemove()
                }
            }
        }
    }
}

/// One reclaimable category: amount, a plain-language reason it's safe, and the
/// action that clears it.
private struct ReclaimCategoryCard: View {
    let icon: String
    let tint: Color
    let title: String
    let amount: String
    let reason: String
    let actionTitle: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                        .fill(tint.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(amount)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                }
                Spacer()
            }

            Text(reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                // Reserve a fixed two-line height so both cards resolve to the
                // same height. `.fixedSize` here made the two unequal-length
                // reasons produce ambiguous heights in the equal-width HStack,
                // whose repeated layout passes made the split view re-scroll the
                // sidebar to the selected row.
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: action) {
                Text(actionTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!isEnabled)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
    }
}

struct DoctorOutputSection: Hashable {
    enum SectionType: Hashable {
        case success, warning, error, info
    }

    let type: SectionType
    let lines: [String]

    var icon: String {
        switch type {
        case .success: return "checkmark.seal.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var gradient: [Color] {
        switch type {
        case .success: return [.green, .mint]
        case .warning: return [.orange, .yellow]
        case .error: return [.red, .pink]
        case .info: return [.blue, .cyan]
        }
    }

    var color: Color {
        switch type {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .info: return .blue
        }
    }
}

struct DoctorSection: View {
    let section: DoctorOutputSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: section.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 26, height: 26)
                    Image(systemName: section.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(section.type == .success ? "All Good!" : (section.lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""))
                    .font(.body.weight(.semibold))
            }

            if section.lines.count > 1 {
                Text(section.lines.dropFirst().joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .strokeBorder(
                    LinearGradient(
                        colors: [section.color.opacity(0.3), section.color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
