//
//  HistoryView.swift
//  Pint
//
//  Created by Antigravity on 26/02/26.
//

import SwiftUI

struct HistoryView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Operation History")
                        .font(.title2.bold())
                    Text("A list of all Homebrew operations performed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                Button(role: .destructive) {
                    viewModel.clearHistory()
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.operationHistory.isEmpty)
            }
            .padding()
            .background(.ultraThinMaterial)

            if viewModel.operationHistory.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    Text("No history yet")
                        .font(.headline)
                    Text("Operations like install, uninstall, and upgrade will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.operationHistory.reversed()) { operation in
                        HistoryRow(operation: operation)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct HistoryRow: View {
    let operation: BrewOperation

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(operation.isSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: operation.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(operation.isSuccess ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(operation.command.capitalized)
                        .font(.headline)
                    Text(operation.packageName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text(operation.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !operation.isSuccess {
                Text("Failed")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
    }
}
