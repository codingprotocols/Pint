//
//  QuarantineView.swift
//  Pint
//
//  Created by Antigravity on 26/02/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct QuarantineView: View {
    @State private var isTargeted = false
    @State private var resultMessage: String?
    @State private var isSuccess = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quarantine Management")
                        .font(.title2.bold())
                    Text("Fix \"App is damaged and can't be opened\" issues")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(24)
            .background(.ultraThinMaterial)

            ScrollView {
                VStack(spacing: 40) {
                    // Drop Area
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isTargeted ? Color.blue : Color.secondary.opacity(0.3),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8])
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
                            )
                            .frame(height: 250)

                        VStack(spacing: 16) {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 64))
                                .foregroundStyle(isTargeted ? .blue : .secondary)

                            Text("Drop App Here")
                                .font(.headline)
                                .foregroundStyle(isTargeted ? .blue : .primary)

                            Text("Drop any .app bundle to remove its quarantine attribute")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    .frame(maxWidth: 500)
                    .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                        guard let provider = providers.first else { return false }
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url = url {
                                fixApp(at: url)
                            }
                        }
                        return true
                    }

                    if let message = resultMessage {
                        HStack(spacing: 8) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(isSuccess ? .green : .red)
                            Text(message)
                                .font(.callout.bold())
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Label("What does this do?", systemImage: "questionmark.circle.fill")
                            .font(.headline)
                        
                        Text("macOS adds a 'quarantine' attribute to apps downloaded from the internet. Sometimes this causes a false \"damaged\" error. This tool runs the following command to clear it:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("xattr -rd com.apple.quarantine /Path/To/App")
                            .font(.system(.caption, design: .monospaced))
                            .padding(10)
                            .background(.quinary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(24)
                    .frame(maxWidth: 500, alignment: .leading)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Quarantine")
    }

    private func fixApp(at url: URL) {
        Task {
            do {
                // Command: xattr -rd com.apple.quarantine path
                _ = try await ShellExecutor.runCustom("/usr/bin/xattr", arguments: ["-rd", "com.apple.quarantine", url.path])
                await MainActor.run {
                    isSuccess = true
                    resultMessage = "Successfully fixed \(url.lastPathComponent)!"
                }
            } catch {
                await MainActor.run {
                    isSuccess = false
                    resultMessage = "Failed to fix app: \(error.localizedDescription)"
                }
            }

            // Clear message after 5 seconds
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                if resultMessage != nil {
                    withAnimation {
                        resultMessage = nil
                    }
                }
            }
        }
    }
}

#Preview {
    QuarantineView()
}
