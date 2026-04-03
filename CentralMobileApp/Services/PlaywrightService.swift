import Foundation
import SwiftUI

/// Service to communicate with the Sophos Playwright backend on grimstarr.
/// Provides access to features not available via the Sophos Central API:
/// Live Discover, threat graphs, policies, screenshots.
actor PlaywrightService {

    static let shared = PlaywrightService()
    private init() {}

    private let keychain = KeychainService.shared

    // MARK: - Configuration

    /// Backend URL — stored in Keychain, configurable in Settings
    private var backendURL: String {
        keychain.read(.playwrightURL) ?? "http://grimstarr.tail3ddb09.ts.net:18870"
    }

    private var secret: String {
        keychain.read(.playwrightSecret) ?? "sophos-pw-2026"
    }

    // MARK: - Health

    struct HealthResponse: Codable {
        let ok: Bool
        let service: String?
        let session: String?
        let browser: String?
    }

    func checkHealth() async throws -> HealthResponse {
        return try await get(path: "/health")
    }

    // MARK: - Session Status

    struct SessionStatus: Codable {
        let ok: Bool
        let status: String
        let url: String?
        let title: String?
        let message: String?
    }

    func sessionStatus() async throws -> SessionStatus {
        return try await get(path: "/api/session/status")
    }

    // MARK: - Screenshot

    func screenshot(url: String? = nil, fullPage: Bool = false) async throws -> Data {
        let body: [String: Any] = [
            "url": url ?? "https://cloud.sophos.com/manage/",
            "fullPage": fullPage,
        ]
        return try await postRaw(path: "/api/screenshot", body: body)
    }

    // MARK: - Live Discover

    struct LiveDiscoverResponse: Codable {
        let ok: Bool
        let query: String?
        let results: LiveDiscoverResults?
        let error: String?
    }

    struct LiveDiscoverResults: Codable {
        let columns: [String]?
        let rows: [[String: String]]?
        let count: Int?
    }

    func runLiveDiscover(query: String) async throws -> LiveDiscoverResponse {
        let body: [String: Any] = ["query": query]
        return try await post(path: "/api/live-discover", body: body)
    }

    // MARK: - Threat Graph

    struct ThreatGraphResponse: Codable {
        let ok: Bool
        let content: String?
        let screenshotBase64: String?
        let error: String?
    }

    func threatGraph(caseId: String? = nil, alertId: String? = nil) async throws -> ThreatGraphResponse {
        var body: [String: Any] = [:]
        if let caseId { body["caseId"] = caseId }
        if let alertId { body["alertId"] = alertId }
        return try await post(path: "/api/threat-graph", body: body)
    }

    // MARK: - Policies

    struct PoliciesResponse: Codable {
        let ok: Bool
        let policies: [PolicyItem]?
        let count: Int?
    }

    struct PolicyItem: Codable, Identifiable {
        var id: String { name }
        let name: String
        let type: String
        let status: String
    }

    func fetchPolicies() async throws -> PoliciesResponse {
        return try await get(path: "/api/policies")
    }

    // MARK: - HTTP Helpers

    private func get<T: Decodable>(path: String) async throws -> T {
        guard let url = URL(string: "\(backendURL)\(path)") else {
            throw PlaywrightError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(secret, forHTTPHeaderField: "X-Playwright-Secret")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PlaywrightError.networkError
        }
        guard (200...299).contains(http.statusCode) else {
            throw PlaywrightError.httpError(http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: "\(backendURL)\(path)") else {
            throw PlaywrightError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(secret, forHTTPHeaderField: "X-Playwright-Secret")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PlaywrightError.networkError
        }
        guard (200...299).contains(http.statusCode) else {
            if let errResp = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw PlaywrightError.serverError(errResp.error ?? "Unknown error")
            }
            throw PlaywrightError.httpError(http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    /// POST that returns raw Data (for screenshots)
    private func postRaw(path: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(backendURL)\(path)") else {
            throw PlaywrightError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(secret, forHTTPHeaderField: "X-Playwright-Secret")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else { throw PlaywrightError.networkError }

        return data
    }

    private struct ErrorResponse: Codable {
        let error: String?
    }
}

// MARK: - Errors

enum PlaywrightError: LocalizedError {
    case invalidURL
    case networkError
    case httpError(Int)
    case serverError(String)
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid Playwright backend URL."
        case .networkError:         return "Cannot reach Playwright backend."
        case .httpError(let code):  return "Playwright backend error \(code)."
        case .serverError(let msg): return msg
        case .sessionExpired:       return "Sophos Central session expired. Re-authenticate on grimstarr."
        }
    }
}
