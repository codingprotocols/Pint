//
//  ServicesViewModel.swift
//  Pint
//
//  Created by Antigravity on 26/02/26.
//

import Foundation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.pint", category: "services-vm")

@MainActor
@Observable
final class ServicesViewModel {
    var services: [BrewServiceItem] = []
    var isLoading: Bool = false
    var refreshInterval: Int = 30 // seconds
    var isAutoRefreshEnabled: Bool = true

    /// Set by ServicesView after init. When non-nil, auto-refresh skips ticks
    /// while a brew operation is in progress to prevent concurrent brew invocations.
    weak var operationRunner: OperationRunner?

    private let brewService: any BrewServiceProtocol
    private var refreshTask: Task<Void, Never>?

    /// Pass a concrete implementation in tests; leave nil for the production default.
    init(brewService: (any BrewServiceProtocol)? = nil) {
        self.brewService = brewService ?? BrewService()
        startAutoRefresh()
    }

    func loadServices() async {
        isLoading = true
        defer { isLoading = false }
        do {
            services = try await brewService.listServices()
        } catch {
            logger.error("Failed to load services: \(error)")
        }
    }

    func startService(_ name: String) async {
        do {
            try await brewService.startService(name)
            await loadServices()
        } catch {
            logger.error("Failed to start service '\(name, privacy: .public)': \(error)")
        }
    }

    func stopService(_ name: String) async {
        do {
            try await brewService.stopService(name)
            await loadServices()
        } catch {
            logger.error("Failed to stop service '\(name, privacy: .public)': \(error)")
        }
    }

    func restartService(_ name: String) async {
        do {
            try await brewService.restartService(name)
            await loadServices()
        } catch {
            logger.error("Failed to restart service '\(name, privacy: .public)': \(error)")
        }
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(refreshInterval))
                guard !Task.isCancelled, isAutoRefreshEnabled else { break }
                // Skip this tick if a brew operation is running to prevent concurrent invocations.
                guard !(operationRunner?.isOperationRunning ?? false) else { continue }
                await loadServices()
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
