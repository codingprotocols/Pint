//
//  SettingsView.swift
//  Pint
//
//  Created by Ajeet Yadav on 23/02/26.
//

import SwiftUI
import ServiceManagement

/// The app's Settings window (accessible via ⌘, or the gear icon).
struct SettingsView: View {
    @AppStorage(AppSettingsKeys.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(AppSettingsKeys.launchAtLogin) private var launchAtLogin = false
    @AppStorage(AppSettingsKeys.updateCheckInterval) private var updateCheckInterval = 3600
    @AppStorage(AppSettingsKeys.notificationsEnabled) private var notificationsEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Show in Menu Bar", isOn: $showMenuBarIcon)
                    .onChange(of: showMenuBarIcon) { _, newValue in
                        if !newValue {
                            NSApp.setActivationPolicy(.regular)
                        }
                    }
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        configureLaunchAtLogin(enabled: newValue)
                    }
            } header: {
                Label("General", systemImage: "gear")
            } footer: {
                if showMenuBarIcon {
                    Text("Pint will stay in the menu bar when you close the window.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Check for Updates", selection: $updateCheckInterval) {
                    ForEach(UpdateCheckInterval.allCases) { interval in
                        Text(interval.label).tag(interval.rawValue)
                    }
                }
                .pickerStyle(.menu)
                Toggle("Send Notifications", isOn: $notificationsEnabled)
            } header: {
                Label("Background Updates", systemImage: "arrow.clockwise")
            } footer: {
                Text("Notifications are sent when operations complete or new updates are found.")
                    .font(.caption).foregroundStyle(.secondary)
            }

        }
        .formStyle(.grouped)
        .frame(width: 440, height: 320)
        .navigationTitle("Settings")
    }

    private func configureLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail — SMAppService may not work in dev builds
            print("Launch at login error: \(error.localizedDescription)")
        }
    }
}
