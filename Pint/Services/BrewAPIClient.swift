//
//  BrewAPIClient.swift
//  Pint
//
//  Created by Ajeet Yadav on 22/02/26.
//

import Foundation
import OSLog

// MARK: - Protocol

/// Abstraction over the Homebrew JSON API and GitHub Releases, primarily for testability.
protocol BrewAPIClientProtocol: Sendable {
    func search(_ query: String) async throws -> [BrewPackage]
    func getInfo(_ name: String, type: PackageType) async throws -> BrewPackage
    /// Returns `nil` when no release notes are available (not a GitHub repo, empty body, API error).
    /// Returns `nil` without caching on GitHub rate-limit (403/429) so future calls retry.
    func fetchReleaseNotes(homepage: String) async -> ReleaseNote?
    /// Downloads and caches the formula and cask lists so the first search is instant.
    func prefetchSearchLists() async
    /// Evicts the formula and cask search lists from the cache.
    /// Call after `brew update` so the next search reflects the updated package database.
    func invalidateSearchCache() async
}

// MARK: - Implementation

/// HTTP client for the Homebrew Formulae JSON API (https://formulae.brew.sh/api/).
/// Used for search and package info — faster than shelling out to `brew`.
actor BrewAPIClient: BrewAPIClientProtocol {

    static let shared = BrewAPIClient()

    // Logger is an actor-isolated instance property to avoid @MainActor cross-actor warnings.
    private let logger = Logger(subsystem: "com.pint", category: "api")

    // MARK: - API Endpoints
    // Marked nonisolated so they can be called from actor-isolated methods without
    // triggering @MainActor cross-actor access warnings (project uses -default-isolation=MainActor).

    private nonisolated static let baseURL = "https://formulae.brew.sh/api"
    private nonisolated static let formulaListURL = URL(string: "\(baseURL)/formula.json")!
    private nonisolated static let caskListURL = URL(string: "\(baseURL)/cask.json")!

    private nonisolated static func formulaDetailURL(_ name: String) -> URL {
        URL(string: "\(baseURL)/formula/\(name).json")!
    }

    private nonisolated static func caskDetailURL(_ name: String) -> URL {
        URL(string: "\(baseURL)/cask/\(name).json")!
    }

    // MARK: - Codable Types

    private struct FormulaListItem: Decodable {
        let name: String
        let fullName: String?
        let desc: String?
        let homepage: String?
        let versions: Versions?
        let caveats: String?

        struct Versions: Decodable {
            let stable: String?
        }

        enum CodingKeys: String, CodingKey {
            case name, desc, homepage, versions, caveats
            case fullName = "full_name"
        }

        var asBrewPackage: BrewPackage {
            BrewPackage(
                name: name,
                version: versions?.stable ?? "",
                description: desc ?? "",
                homepage: homepage ?? "",
                type: .formula,
                caveats: caveats.flatMap { $0.isEmpty ? nil : $0 }
            )
        }
    }

    private struct CaskListItem: Decodable {
        let token: String
        let desc: String?
        let homepage: String?
        let version: String?
        let name: [String]?

        var asBrewPackage: BrewPackage {
            BrewPackage(
                name: token,
                version: version ?? "",
                description: desc ?? "",
                homepage: homepage ?? "",
                type: .cask
            )
        }
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let name: String?
        let body: String?
        let publishedAt: String?
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name, body
            case publishedAt = "published_at"
            case htmlURL = "html_url"
        }
    }

    // MARK: - Cache

    private struct CachedFormulaeList {
        let items: [FormulaListItem]
        let fetchedAt: Date
    }

    private struct CachedCaskList {
        let items: [CaskListItem]
        let fetchedAt: Date
    }

    private struct CachedRelease {
        let note: ReleaseNote?
        let fetchedAt: Date
    }

    private var formulaCache: CachedFormulaeList?
    private var caskCache: CachedCaskList?
    private var releaseNoteCache: [String: CachedRelease] = [:]

    private let cacheTTL: TimeInterval = 600        // 10 minutes for formula/cask lists
    private let releaseNoteCacheTTL: TimeInterval = 3600 // 1 hour for release notes

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    // MARK: - Memory Management (tiered by severity)

    /// Clear only the release note cache — called on memory `.warning`.
    func clearReleaseNoteCache() {
        releaseNoteCache.removeAll()
        logger.debug("Release note cache cleared (memory warning)")
    }

    /// Clear all in-memory caches — called on memory `.critical`.
    func clearCaches() {
        formulaCache = nil
        caskCache = nil
        releaseNoteCache.removeAll()
        logger.debug("All caches cleared (memory critical)")
    }

    func invalidateSearchCache() {
        formulaCache = nil
        caskCache = nil
        logger.debug("Search cache invalidated after brew update")
    }

    /// Registers a one-time memory pressure observer that clears caches in proportion to severity.
    /// `.warning` → release notes only; `.critical` → everything.
    private nonisolated static let memoryPressureSource: DispatchSourceMemoryPressure = {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler {
            let event = source.data
            Task {
                if event.contains(.critical) {
                    await BrewAPIClient.shared.clearCaches()
                } else if event.contains(.warning) {
                    await BrewAPIClient.shared.clearReleaseNoteCache()
                }
            }
        }
        source.resume()
        return source
    }()

    private func ensureMemoryObserver() {
        _ = Self.memoryPressureSource
    }

    // MARK: - Prefetch

    func prefetchSearchLists() async {
        async let _ = try? fetchFormulaList()
        async let _ = try? fetchCaskList()
    }

    // MARK: - Search

    func searchFormulae(_ query: String) async throws -> [BrewPackage] {
        let list = try await fetchFormulaList()
        return list
            .filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                ($0.desc ?? "").localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.name.localizedCaseInsensitiveContains(query) && !$1.name.localizedCaseInsensitiveContains(query) }
            .prefix(50)
            .map(\.asBrewPackage)
    }

    func searchCasks(_ query: String) async throws -> [BrewPackage] {
        let list = try await fetchCaskList()
        return list
            .filter {
                $0.token.localizedCaseInsensitiveContains(query) ||
                ($0.name ?? []).joined(separator: " ").localizedCaseInsensitiveContains(query) ||
                ($0.desc ?? "").localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.token.localizedCaseInsensitiveContains(query) && !$1.token.localizedCaseInsensitiveContains(query) }
            .prefix(50)
            .map(\.asBrewPackage)
    }

    func search(_ query: String) async throws -> [BrewPackage] {
        async let formulae = searchFormulae(query)
        async let casks = searchCasks(query)
        return try await formulae + casks
    }

    // MARK: - Detail Info

    func getFormulaInfo(_ name: String) async throws -> BrewPackage {
        let url = Self.formulaDetailURL(name)
        let (data, _) = try await session.data(from: url)
        let item = try JSONDecoder().decode(FormulaListItem.self, from: data)
        return item.asBrewPackage
    }

    func getCaskInfo(_ name: String) async throws -> BrewPackage {
        let url = Self.caskDetailURL(name)
        let (data, _) = try await session.data(from: url)
        let item = try JSONDecoder().decode(CaskListItem.self, from: data)
        return item.asBrewPackage
    }

    func getInfo(_ name: String, type: PackageType) async throws -> BrewPackage {
        switch type {
        case .formula: return try await getFormulaInfo(name)
        case .cask: return try await getCaskInfo(name)
        }
    }

    // MARK: - List Fetching (Cached)

    private func fetchFormulaList() async throws -> [FormulaListItem] {
        if let cache = formulaCache, Date().timeIntervalSince(cache.fetchedAt) < cacheTTL {
            return cache.items
        }
        let (data, _) = try await session.data(from: Self.formulaListURL)
        let items = try JSONDecoder().decode([FormulaListItem].self, from: data)
        formulaCache = CachedFormulaeList(items: items, fetchedAt: Date())
        return items
    }

    private func fetchCaskList() async throws -> [CaskListItem] {
        if let cache = caskCache, Date().timeIntervalSince(cache.fetchedAt) < cacheTTL {
            return cache.items
        }
        let (data, _) = try await session.data(from: Self.caskListURL)
        let items = try JSONDecoder().decode([CaskListItem].self, from: data)
        caskCache = CachedCaskList(items: items, fetchedAt: Date())
        return items
    }

    // MARK: - GitHub Release Notes

    func fetchReleaseNotes(homepage: String) async -> ReleaseNote? {
        ensureMemoryObserver()
        guard let (owner, repo) = parseGitHubRepo(from: homepage) else { return nil }

        let cacheKey = "\(owner)/\(repo)"

        if let cached = releaseNoteCache[cacheKey],
           Date().timeIntervalSince(cached.fetchedAt) < releaseNoteCacheTTL {
            return cached.note
        }

        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10

            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
                    // Rate limited — do NOT cache so future requests retry when limit resets.
                    logger.warning("GitHub API rate limit hit for \(owner)/\(repo, privacy: .public) (status \(httpResponse.statusCode))")
                    return nil
                }
                guard httpResponse.statusCode == 200 else {
                    logger.debug("GitHub API returned \(httpResponse.statusCode) for \(owner)/\(repo, privacy: .public)")
                    releaseNoteCache[cacheKey] = CachedRelease(note: nil, fetchedAt: Date())
                    return nil
                }
            }

            let decoded = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let body = decoded.body ?? ""
            guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                releaseNoteCache[cacheKey] = CachedRelease(note: nil, fetchedAt: Date())
                return nil
            }

            let note = ReleaseNote(
                tagName: decoded.tagName,
                title: decoded.name ?? decoded.tagName,
                body: body,
                publishedAt: formatDate(decoded.publishedAt ?? ""),
                htmlURL: decoded.htmlURL
            )
            releaseNoteCache[cacheKey] = CachedRelease(note: note, fetchedAt: Date())
            return note

        } catch {
            logger.error("Failed to fetch release notes for \(owner)/\(repo, privacy: .public): \(error)")
            // Cache the failure to avoid hammering the API on transient errors.
            releaseNoteCache[cacheKey] = CachedRelease(note: nil, fetchedAt: Date())
            return nil
        }
    }

    // MARK: - Helpers

    private func parseGitHubRepo(from urlString: String) -> (owner: String, repo: String)? {
        guard let url = URL(string: urlString),
              let host = url.host,
              host.contains("github.com") else {
            return nil
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 2 else { return nil }
        return (pathComponents[0], pathComponents[1])
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .none
            return display.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .none
            return display.string(from: date)
        }
        return isoString
    }
}
