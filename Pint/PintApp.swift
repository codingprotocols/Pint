//
//  PintApp.swift
//  Pint
//
//  Created by Ajeet Yadav on 22/02/26.
//

import Sparkle
import SwiftUI

// MARK: - Menu Bar Settings

/// Separate @Observable model for menu bar visibility.
/// Lives outside AppDelegate so @Observable tracking works cleanly in App.body.
@Observable
final class MenuBarSettings {
    var isInserted: Bool =
        UserDefaults.standard.object(forKey: AppSettingsKeys.showMenuBarIcon) as? Bool ?? true

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func defaultsChanged() {
        let newValue = UserDefaults.standard.object(forKey: AppSettingsKeys.showMenuBarIcon) as? Bool ?? true
        guard isInserted != newValue else { return }
        isInserted = newValue
    }
}

// MARK: - App

@main
struct PintApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = AppViewModel()
    @State private var menuBarSettings = MenuBarSettings()

    /// Accessing menuBarSettings.isInserted here registers the @Observable
    /// dependency, so App.body re-evaluates whenever isInserted changes.
    private var menuBarBinding: Binding<Bool> {
        let current = menuBarSettings.isInserted
        return Binding(
            get: { current },
            set: { [menuBarSettings] in menuBarSettings.isInserted = $0 }
        )
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(viewModel)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    appDelegate.viewModel = viewModel
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: appDelegate.updaterController.updater)
            }
        }

        Settings {
            SettingsView()
        }

        MenuBarExtra(isInserted: menuBarBinding) {
            MenuBarView()
                .environment(viewModel)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.hasUpdates ? "arrow.up.circle.fill" : "mug.fill")
                if viewModel.hasUpdates {
                    Text("\(viewModel.outdatedPackages.count)")
                        .font(.caption.weight(.bold))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    var viewModel: AppViewModel?

    /// Sparkle updater controller — started at launch, drives "Check for Updates…".
    /// Initialised as a stored property so it lives for the app's lifetime.
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        viewModel?.requestNotificationPermission()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let menuBarEnabled = UserDefaults.standard.object(forKey: AppSettingsKeys.showMenuBarIcon) as? Bool ?? true
        if menuBarEnabled {
            DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
            return false
        }
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.setActivationPolicy(.regular)
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
        return true
    }
}
