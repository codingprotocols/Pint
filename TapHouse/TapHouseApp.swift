//
//  TapHouseApp.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

@main
struct TapHouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = AppViewModel()
    @AppStorage(AppSettingsKeys.showMenuBarIcon) private var showMenuBarIcon = true

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(viewModel)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    appDelegate.viewModel = viewModel
                    appDelegate.menuBarEnabled = showMenuBarIcon
                }
                .onChange(of: showMenuBarIcon) { _, newValue in
                    appDelegate.menuBarEnabled = newValue
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 720)

        // Settings window (⌘,)
        Settings {
            SettingsView()
        }

        // Menu bar icon + popover
        MenuBarExtra(
            "TapHouse",
            systemImage: viewModel.hasUpdates
                ? "arrow.up.circle.fill"
                : "mug.fill",
            isInserted: $showMenuBarIcon
        ) {
            MenuBarView()
                .environment(viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Delegate

/// Handles window close → hide (when menu bar is active) and dock icon management.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var viewModel: AppViewModel?
    var menuBarEnabled: Bool = true

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when closing the window if menu bar is active
        if menuBarEnabled {
            // Hide from dock when all windows are closed
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
            }
            return false
        }
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Re-show the window when clicking the dock icon
        if !flag {
            NSApp.setActivationPolicy(.regular)
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure dock icon is visible on launch
        NSApp.setActivationPolicy(.regular)
    }
}
