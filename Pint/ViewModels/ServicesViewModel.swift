//
//  ServicesViewModel.swift
//  Pint
//
//  Created by Antigravity on 26/02/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ServicesViewModel {
    var services: [BrewServiceItem] = []
    var isLoading: Bool = false
    var refreshInterval: Int = 30 // Seconds
    var isAutoRefreshEnabled: Bool = true

    private let brewService = BrewService()
    private var refreshTask: Task<Void, Never>?

    init() {
        startAutoRefresh()
    }

    func loadServices() async {
        isLoading = true
        defer { isLoading = false }
        do {
            services = try await brewService.listServices()
        } catch {
            print("Failed to load services: \(error)")
        }
    }

    func startService(_ name: String) async {
        do {
            try await brewService.startService(name)
            await loadServices()
        } catch {
            print("Failed to start service \(name): \(error)")
        }
    }

    func stopService(_ name: String) async {
        do {
            try await brewService.stopService(name)
            await loadServices()
        } catch {
            print("Failed to stop service \(name): \(error)")
        }
    }

    func restartService(_ name: String) async {
        do {
            try await brewService.restartService(name)
            await loadServices()
        } catch {
            print("Failed to restart service \(name): \(error)")
        }
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                await loadServices()
                try? await Task.sleep(for: .seconds(refreshInterval))
                guard isAutoRefreshEnabled else { break }
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func toggleAutoRefresh() {
        isAutoRefreshEnabled.toggle()
        if isAutoRefreshEnabled {
            startAutoRefresh()
        } else {
            stopAutoRefresh()
        }
    }
}
