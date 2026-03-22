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

            // New Diagnostics Cards
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Disk Usage", systemImage: "info.circle")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(viewModel.diskUsage.isEmpty ? "Calculating..." : viewModel.diskUsage.split(separator: "\t").first ?? "--")
                            .font(.system(.title, design: .rounded, weight: .bold))
                        Text("in cache")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.controlColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Label("Cache Cleanup", systemImage: "trash")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Button {
                        viewModel.cleanupCache()
                    } label: {
                        Text("Clean Cache")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.controlColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
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
            Task { await viewModel.loadDiskUsage() }
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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
