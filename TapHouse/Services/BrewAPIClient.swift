//
//  BrewAPIClient.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import Foundation

/// HTTP client for the Homebrew Formulae JSON API (https://formulae.brew.sh/api/).
/// Used for search and package info — faster than shelling out to `brew`.
actor BrewAPIClient {

    static let shared = BrewAPIClient()

    // MARK: - API Endpoints

    private static let baseURL = "https://formulae.brew.sh/api"
    private static let formulaListURL = URL(string: "\(baseURL)/formula.json")!
    private static let caskListURL = URL(string: "\(baseURL)/cask.json")!

    private static func formulaDetailURL(_ name: String) -> URL {
        URL(string: "\(baseURL)/formula/\(name).json")!
    }

    private static func caskDetailURL(_ name: String) -> URL {
        URL(string: "\(baseURL)/cask/\(name).json")!
    }

    // MARK: - Cache

    private struct CachedList {
        let items: [[String: Any]]
        let fetchedAt: Date
    }

    private var formulaCache: CachedList?
    private var caskCache: CachedList?
    private let cacheTTL: TimeInterval = 600 // 10 minutes

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    // MARK: - Search

    /// Search all formulae matching the query string (case-insensitive substring match).
    func searchFormulae(_ query: String) async throws -> [BrewPackage] {
        let list = try await fetchFormulaList()
        let lowered = query.lowercased()
        return list
            .filter { ($0["name"] as? String ?? "").lowercased().contains(lowered) }
            .prefix(50)
            .map { parseFormulaDict($0) }
    }

    /// Search all casks matching the query string.
    func searchCasks(_ query: String) async throws -> [BrewPackage] {
        let list = try await fetchCaskList()
        let lowered = query.lowercased()
        return list
            .filter {
                let token = ($0["token"] as? String ?? "").lowercased()
                let names = ($0["name"] as? [String])?.joined(separator: " ").lowercased() ?? ""
                return token.contains(lowered) || names.contains(lowered)
            }
            .prefix(50)
            .map { parseCaskDict($0) }
    }

    /// Combined search across both formulae and casks.
    func search(_ query: String) async throws -> [BrewPackage] {
        async let formulae = searchFormulae(query)
        async let casks = searchCasks(query)
        return try await formulae + casks
    }

    // MARK: - Detail Info

    /// Get detailed info for a formula by name via the API.
    func getFormulaInfo(_ name: String) async throws -> BrewPackage {
        let url = Self.formulaDetailURL(name)
        let (data, _) = try await session.data(from: url)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return BrewPackage(name: name, type: .formula)
        }
        return parseFormulaDict(dict)
    }

    /// Get detailed info for a cask by name via the API.
    func getCaskInfo(_ name: String) async throws -> BrewPackage {
        let url = Self.caskDetailURL(name)
        let (data, _) = try await session.data(from: url)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return BrewPackage(name: name, type: .cask)
        }
        return parseCaskDict(dict)
    }

    /// Get info for a package by name and type.
    func getInfo(_ name: String, type: PackageType) async throws -> BrewPackage {
        switch type {
        case .formula:
            return try await getFormulaInfo(name)
        case .cask:
            return try await getCaskInfo(name)
        }
    }

    // MARK: - List Fetching (Cached)

    private func fetchFormulaList() async throws -> [[String: Any]] {
        if let cache = formulaCache, Date().timeIntervalSince(cache.fetchedAt) < cacheTTL {
            return cache.items
        }
        let (data, _) = try await session.data(from: Self.formulaListURL)
        guard let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        formulaCache = CachedList(items: list, fetchedAt: Date())
        return list
    }

    private func fetchCaskList() async throws -> [[String: Any]] {
        if let cache = caskCache, Date().timeIntervalSince(cache.fetchedAt) < cacheTTL {
            return cache.items
        }
        let (data, _) = try await session.data(from: Self.caskListURL)
        guard let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        caskCache = CachedList(items: list, fetchedAt: Date())
        return list
    }

    // MARK: - Parsing

    private func parseFormulaDict(_ dict: [String: Any]) -> BrewPackage {
        let name = dict["name"] as? String ?? dict["full_name"] as? String ?? ""
        let desc = dict["desc"] as? String ?? ""
        let homepage = dict["homepage"] as? String ?? ""

        var version = ""
        if let versions = dict["versions"] as? [String: Any] {
            version = versions["stable"] as? String ?? ""
        }

        return BrewPackage(
            name: name,
            version: version,
            description: desc,
            homepage: homepage,
            type: .formula
        )
    }

    private func parseCaskDict(_ dict: [String: Any]) -> BrewPackage {
        let token = dict["token"] as? String ?? ""
        let desc = dict["desc"] as? String ?? ""
        let homepage = dict["homepage"] as? String ?? ""
        let version = dict["version"] as? String ?? ""

        return BrewPackage(
            name: token,
            version: version,
            description: desc,
            homepage: homepage,
            type: .cask
        )
    }

    // MARK: - GitHub Release Notes

    /// Fetch the latest release notes from GitHub for a package.
    /// Returns `nil` if the homepage is not a GitHub repo or the API call fails.
    func fetchReleaseNotes(homepage: String) async -> ReleaseNote? {
        guard let (owner, repo) = parseGitHubRepo(from: homepage) else { return nil }

        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10

            let (data, response) = try await session.data(for: request)

            // Check for rate limit or not-found
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                return nil
            }

            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            let tagName = dict["tag_name"] as? String ?? ""
            let title = dict["name"] as? String ?? tagName
            let body = dict["body"] as? String ?? ""
            let publishedAt = dict["published_at"] as? String ?? ""
            let htmlURL = dict["html_url"] as? String ?? ""

            // Skip if there's no meaningful content
            guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }

            return ReleaseNote(
                tagName: tagName,
                title: title,
                body: body,
                publishedAt: formatDate(publishedAt),
                htmlURL: htmlURL
            )
        } catch {
            return nil
        }
    }

    /// Extract owner/repo from a GitHub URL like "https://github.com/owner/repo" or "https://github.com/owner/repo/..."
    private func parseGitHubRepo(from urlString: String) -> (owner: String, repo: String)? {
        guard let url = URL(string: urlString),
              let host = url.host,
              host.contains("github.com") else {
            return nil
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 2 else { return nil }

        let owner = pathComponents[0]
        let repo = pathComponents[1]
        return (owner, repo)
    }

    /// Format an ISO 8601 date string into a human-readable form.
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .none
            return display.string(from: date)
        }
        // Try without fractional seconds
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
