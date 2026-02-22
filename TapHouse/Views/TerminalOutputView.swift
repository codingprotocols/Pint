//
//  TerminalOutputView.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

struct TerminalOutputView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Circle().fill(.red).frame(width: 12, height: 12)
                Circle().fill(.yellow).frame(width: 12, height: 12)
                Circle().fill(.green).frame(width: 12, height: 12)

                Spacer()

                if let op = viewModel.activeOperation {
                    Text("brew \(op.command) \(op.packageName)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.activeOperation?.isComplete == true {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.black.opacity(0.3))

            Divider()

            // Terminal content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let op = viewModel.activeOperation {
                            HStack(spacing: 4) {
                                Text("$")
                                    .foregroundStyle(.green)
                                Text("brew \(op.command) \(op.packageName)")
                                    .foregroundStyle(.white)
                            }
                            .font(.system(.body, design: .monospaced))
                            .padding(.bottom, 8)

                            Text(op.output)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if op.isComplete {
                                Divider()
                                    .background(.white.opacity(0.2))
                                    .padding(.vertical, 8)

                                HStack(spacing: 6) {
                                    Image(systemName: op.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(op.isSuccess ? .green : .red)
                                    Text(op.isSuccess ? "Completed successfully" : "Operation failed")
                                        .foregroundStyle(op.isSuccess ? .green : .red)
                                }
                                .font(.system(.body, design: .monospaced))
                            } else {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                    Text("Running…")
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .font(.system(.caption, design: .monospaced))
                                .padding(.top, 4)
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: viewModel.activeOperation?.output) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom")
                    }
                }
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
        .frame(minWidth: 600, minHeight: 400)
    }
}
