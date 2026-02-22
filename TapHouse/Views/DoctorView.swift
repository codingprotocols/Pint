//
//  DoctorView.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

struct DoctorView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brew Doctor")
                        .font(.largeTitle.weight(.bold))
                    Text("Diagnose your Homebrew installation")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button {
                    Task { await viewModel.loadDoctor() }
                } label: {
                    Label("Run Diagnostics", systemImage: "stethoscope")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding()

            Divider()

            if viewModel.isLoadingDoctor {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Running brew doctor…")
                        .font(.headline)
                    Text("This may take a moment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if viewModel.doctorOutput.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("No diagnostics yet")
                        .font(.title2.weight(.medium))
                    Text("Click \"Run Diagnostics\" to check your Homebrew installation.")
                        .font(.caption)
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
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(.background)
        .onAppear {
            if viewModel.doctorOutput.isEmpty {
                Task { await viewModel.loadDoctor() }
            }
        }
    }

    private func parseDoctorOutput() -> [DoctorOutputSection] {
        let lines = viewModel.doctorOutput.components(separatedBy: "\n")
        var sections: [DoctorOutputSection] = []
        var currentType: DoctorOutputSection.SectionType = .info
        var currentLines: [String] = []

        for line in lines {
            if line.hasPrefix("Warning:") || line.hasPrefix("Error:") {
                if !currentLines.isEmpty {
                    sections.append(DoctorOutputSection(type: currentType, lines: currentLines))
                }
                currentType = line.hasPrefix("Warning:") ? .warning : .error
                currentLines = [line]
            } else if line.contains("Your system is ready to brew.") {
                if !currentLines.isEmpty {
                    sections.append(DoctorOutputSection(type: currentType, lines: currentLines))
                }
                sections.append(DoctorOutputSection(type: .success, lines: [line]))
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }

        if !currentLines.isEmpty {
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: section.icon)
                    .foregroundStyle(section.color)
                Text(section.type == .success ? "All Good!" : section.lines.first ?? "")
                    .font(.body.weight(.medium))
            }

            if section.lines.count > 1 {
                Text(section.lines.dropFirst().joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(section.color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(section.color.opacity(0.2), lineWidth: 1)
        )
    }
}
