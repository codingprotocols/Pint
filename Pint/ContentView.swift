//
//  ContentView.swift
//  Pint
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

/// Root view with NavigationSplitView layout.
struct ContentView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel

        NavigationSplitView {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                Group {
                    switch viewModel.selectedNav {
                    case .dashboard:
                        DashboardView()
                    case .installed:
                        InstalledView()
                    case .services:
                        ServicesView()
                    case .taps:
                        TapsView()
                    case .quarantine:
                        QuarantineView()
                    case .history:
                        HistoryView()
                    case .upgrades:
                        UpgradesView()
                    case .search:
                        SearchView()
                    case .backup:
                        BackupView()
                    case .doctor:
                        DoctorView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Inline operation banner at the bottom
                OperationBannerView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            viewModel.loadAll()
        }
        .overlay(alignment: .top) {
            if let message = viewModel.backgroundError {
                BackgroundErrorBanner(message: message) {
                    viewModel.backgroundError = nil
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: viewModel.backgroundError != nil)
            }
        }
        // Global keyboard shortcuts — hidden buttons respond even when unfocused.
        .background {
            Group {
                Button("") { viewModel.refreshCurrentView() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("") { viewModel.selectedNav = .search }
                    .keyboardShortcut("k", modifiers: .command)
                Button("") { viewModel.selectedNav = .upgrades }
                    .keyboardShortcut("u", modifiers: [.command, .shift])
            }
            .opacity(0)
            .allowsHitTesting(false)
        }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .overlay {
            if viewModel.isCheckingBrew {
                Color(.windowBackgroundColor).ignoresSafeArea()
                    .overlay(ProgressView().controlSize(.large))
            } else if !viewModel.brewAvailable {
                BrewNotFoundView(reason: viewModel.brewNotFoundReason) {
                    viewModel.isCheckingBrew = true
                    viewModel.loadAll()
                }
            }
        }
    }
}

// MARK: - Background Error Banner

/// Non-intrusive banner shown when a background update check fails silently.
/// Does not interrupt the user — dismissible by clicking ✕.
struct BackgroundErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text("Background check failed: \(message)")
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(.orange.opacity(0.4)), alignment: .bottom)
        .frame(maxWidth: .infinity)
    }
}

/// Overlay shown when Homebrew cannot be located — shows tailored instructions
/// for either a fresh install or a PATH configuration issue.
struct BrewNotFoundView: View {
    let reason: BrewNotFoundReason
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color(.windowBackgroundColor).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Icon + title
                    VStack(spacing: 12) {
                        Image(systemName: reason == .notInstalled ? "mug.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(reason == .notInstalled ? Color.secondary : Color.orange)

                        Text(reason == .notInstalled ? "Homebrew Not Found" : "Homebrew PATH Not Configured")
                            .font(.largeTitle.bold())

                        Text(reason == .notInstalled
                             ? "Pint requires Homebrew to manage packages.\nFollow the steps below to install it."
                             : "Homebrew is installed but not at a standard location.\nFollow the steps below to configure your shell PATH.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Instruction card
                    switch reason {
                    case .notInstalled:
                        InstallInstructionsCard()
                    case .pathNotConfigured(let brewPath):
                        PathInstructionsCard(brewPath: brewPath)
                    }

                    // Actions
                    HStack(spacing: 16) {
                        if reason == .notInstalled {
                            Link(destination: URL(string: "https://brew.sh")!) {
                                Label("brew.sh", systemImage: "safari")
                            }
                            .foregroundStyle(.blue)
                        }

                        Button { onRetry() } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(40)
            }
        }
    }
}

// MARK: - Install Instructions

private struct InstallInstructionsCard: View {
    private let installCommand =
        "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

    // After Homebrew installs, the user must run shellenv to configure PATH.
    // The correct path depends on the chip architecture.
    #if arch(arm64)
    private let shellenvCommand = "eval \"$(/opt/homebrew/bin/brew shellenv)\""
    private let shellenvPersist = "echo 'eval \"$(/opt/homebrew/bin/brew shellenv)\"' >> ~/.zprofile"
    private let chipNote = "Apple Silicon (M1 and later)"
    #else
    private let shellenvCommand = "eval \"$(/usr/local/bin/brew shellenv)\""
    private let shellenvPersist = "echo 'eval \"$(/usr/local/bin/brew shellenv)\"' >> ~/.zprofile"
    private let chipNote = "Intel Mac"
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("How to Install Homebrew", systemImage: "terminal.fill")
                .font(.headline)

            BrewStep(number: "1", text: "Open **Terminal**  (⌘ Space → type \"Terminal\" → Return)")

            BrewStep(number: "2", text: "Paste and run the install script:")
            CopyableCommandBlock(command: installCommand)

            BrewStep(number: "3", text: "Follow all on-screen prompts. When the installer finishes it will print a **\"Next steps\"** section.")

            BrewStep(number: "4", text: "Configure your shell PATH **(\(chipNote))**. Run this in the same Terminal window:")
            CopyableCommandBlock(command: shellenvPersist)

            BrewStep(number: "5", text: "Open a **new** Terminal window and verify the install:")
            CopyableCommandBlock(command: "brew --version")

            BrewStep(number: "6", text: "Click **Retry** below to launch Pint.")
        }
        .padding(20)
        .frame(maxWidth: 580, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 8, y: 2)
    }
}

// MARK: - PATH Instructions

private struct PathInstructionsCard: View {
    let brewPath: String

    // Derive the directory containing the brew binary for shellenv.
    private var brewPrefix: String {
        // /some/path/bin/brew → /some/path/bin
        (brewPath as NSString).deletingLastPathComponent
    }

    private var shellenvPersist: String {
        "echo 'eval \"$(\(brewPath) shellenv)\"' >> ~/.zprofile"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("How to Configure Homebrew PATH", systemImage: "terminal.fill")
                .font(.headline)

            // Show where brew was found
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Homebrew found at a non-standard path:")
                        .font(.callout)
                    Text(brewPath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.green.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Pint looks for brew at `/opt/homebrew/bin/brew` (Apple Silicon) or `/usr/local/bin/brew` (Intel). Your brew is at a different location. You need to add it to your shell profile so all tools — including Pint — can find it.")
                .font(.callout)
                .foregroundStyle(.secondary)

            BrewStep(number: "1", text: "Open **Terminal**  (⌘ Space → type \"Terminal\" → Return)")

            BrewStep(number: "2", text: "Add Homebrew to your **zsh** profile (default shell on macOS):")
            CopyableCommandBlock(command: shellenvPersist)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle").foregroundStyle(.blue).font(.caption)
                Text("Using **bash** instead? Replace `~/.zprofile` with `~/.bash_profile`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            BrewStep(number: "3", text: "Apply the changes to the current session:")
            CopyableCommandBlock(command: "source ~/.zprofile")

            BrewStep(number: "4", text: "Click **Retry** below.")
        }
        .padding(20)
        .frame(maxWidth: 580, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 8, y: 2)
    }
}

// MARK: - Shared sub-components

private struct BrewStep: View {
    let number: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
            Text(text).font(.callout)
        }
    }
}

private struct CopyableCommandBlock: View {
    let command: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(width: 36, height: 36)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help(copied ? "Copied!" : "Copy to clipboard")
        }
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1))
    }
}
