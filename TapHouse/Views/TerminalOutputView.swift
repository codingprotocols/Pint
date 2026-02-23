//
//  TerminalOutputView.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

/// Inline banner that shows the active brew operation at the bottom of the window.
/// Replaces the previous separate terminal sheet.
struct OperationBannerView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var isExpanded = false

    var body: some View {
        if let op = viewModel.activeOperation {
            VStack(spacing: 0) {
                Divider()

                VStack(spacing: 0) {
                    // Header row — always visible
                    HStack(spacing: 10) {
                        // Status icon
                        if op.isComplete {
                            Image(systemName: op.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(op.isSuccess ? .green : .red)
                                .font(.body)
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }

                        // Command label
                        Text("brew \(op.command) \(op.packageName)")
                            .font(.system(.callout, design: .monospaced))
                            .lineLimit(1)

                        Spacer()

                        // Action buttons
                        HStack(spacing: 8) {
                            // Expand / collapse toggle
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(.plain)
                            .help(isExpanded ? "Collapse" : "Expand")

                            if !op.isComplete {
                                Button {
                                    viewModel.cancelOperation()
                                } label: {
                                    Label("Cancel", systemImage: "xmark.circle")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.red)
                            } else {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.dismissOperation()
                                    }
                                } label: {
                                    Label("Dismiss", systemImage: "xmark")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    // Expandable terminal output
                    if isExpanded {
                        Divider()

                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 4) {
                                        Text("$")
                                            .foregroundStyle(.green)
                                        Text("brew \(op.command) \(op.packageName)")
                                            .foregroundStyle(.white)
                                    }
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.bottom, 6)

                                    Text(op.output)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if op.isComplete {
                                        HStack(spacing: 6) {
                                            Image(systemName: op.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundStyle(op.isSuccess ? .green : .red)
                                            Text(op.isSuccess ? "Completed successfully" : "Operation failed")
                                                .foregroundStyle(op.isSuccess ? .green : .red)
                                        }
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(.top, 6)
                                    }

                                    Color.clear
                                        .frame(height: 1)
                                        .id("bottom")
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 200)
                            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                            .onChange(of: op.output) { _, _ in
                                withAnimation {
                                    proxy.scrollTo("bottom")
                                }
                            }
                        }
                    }
                }
                .background(.bar)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                // Auto-expand when a new operation starts
                isExpanded = true
            }
        }
    }
}
