//
//  TerminalOutputView.swift
//  Pint
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

/// Inline operation banner that appears at the bottom of the detail pane.
struct OperationBannerView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var isExpanded = false

    var body: some View {
        if let op = viewModel.activeOperation {
            VStack(spacing: 0) {
                Divider()

                VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 10) {
                        // Status icon
                        if !op.isComplete {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(
                                        op.isSuccess
                                            ? LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            : LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 20, height: 20)
                                Image(systemName: op.isSuccess ? "checkmark" : "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                        // Command label
                        VStack(alignment: .leading, spacing: 2) {
                            Text(op.isComplete ? (op.isSuccess ? "Completed" : "Failed") : "Running…")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(
                                    op.isComplete
                                        ? (op.isSuccess ? .green : .red)
                                        : .orange
                                )
                            Text("brew \(op.command) \(op.packageName)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            // Expand/collapse toggle
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, height: 24)
                                    .background(.quaternary.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                            .help(isExpanded ? "Collapse" : "Expand")

                            // Cancel / Dismiss
                            if !op.isComplete {
                                Button {
                                    viewModel.cancelOperation()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark")
                                        Text("Cancel")
                                    }
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.red.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    viewModel.dismissOperation()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24, height: 24)
                                        .background(.quaternary.opacity(0.5))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                .buttonStyle(.plain)
                                .help("Dismiss")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    // Expandable output
                    if isExpanded {
                        Divider()
                        ScrollViewReader { proxy in
                            ScrollView {
                                Text(op.output)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .id("output-bottom")
                            }
                            .frame(height: 160)
                            .background(.black.opacity(0.03))
                            .onChange(of: op.output) { _, _ in
                                withAnimation(.easeOut(duration: 0.1)) {
                                    proxy.scrollTo("output-bottom", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .background(.ultraThinMaterial)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
