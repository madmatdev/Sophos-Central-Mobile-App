import Foundation

actor SophosAPIService {

    static let shared = SophosAPIService()
    private init() {}

    private let auth = AuthService.shared
    private let keychain = KeychainService.shared

    // MARK: - Base URL

    private var baseURL: String {
        keychain.read(.dataRegionURL) ?? "https://api.central.sophos.com"
    }

    private var tenantId: String {
        keychain.read(.tenantId) ?? ""
    }

    // MARK: - Account Health

    func fetchAccountHealth() async throws -> AccountHealthResponse {
        let url = "\(baseURL)/account-health-check/v1/health-check"
        return try await get(url: url)
    }

    // MARK: - Alerts

    func fetchAlerts(pageSize: Int = 100, severity: String? = nil) async throws -> AlertsResponse {
        var params = ["pageSize": "\(pageSize)", "orderBy": "raisedAt:desc"]
        if let severity { params["severities"] = severity }
        let url = buildURL("\(baseURL)/common/v1/alerts", params: params)
        return try await get(url: url)
    }

    func acknowledgeAlert(alertId: String) async throws {
        let url = "\(baseURL)/common/v1/alerts/\(alertId)/actions"
        let body: [String: Any] = [
            "action": "acknowledge",
            "message": "Acknowledged via Sophos Central Mobile"
        ]
        let _: EmptyResponse = try await post(url: url, body: body)
    }

    // MARK: - Endpoints

    func fetchEndpoints(pageSize: Int = 500) async throws -> EndpointsResponse {
        let params = ["pageSize": "\(pageSize)", "view": "full"]
        let url = buildURL("\(baseURL)/endpoint/v1/endpoints", params: params)
        return try await get(url: url)
    }

    func fetchEndpoint(id: String) async throws -> SophosEndpoint {
        let url = buildURL("\(baseURL)/endpoint/v1/endpoints/\(id)", params: ["view": "full"])
        return try await get(url: url)
    }

    // MARK: - Isolation

    func isolateEndpoint(id: String, comment: String? = nil) async throws -> IsolationResponse {
        let url = "\(baseURL)/endpoint/v1/endpoints/\(id)/isolation"
        let body: [String: Any] = [
            "enabled": true,
            "comment": comment ?? "Isolated via Sophos Central Mobile"
        ]
        return try await post(url: url, body: body)
    }

    func deIsolateEndpoint(id: String) async throws -> IsolationResponse {
        let url = "\(baseURL)/endpoint/v1/endpoints/\(id)/isolation"
        let body: [String: Any] = ["enabled": false]
        return try await patch(url: url, body: body)
    }

    func fetchIsolationStatus(id: String) async throws -> IsolationResponse {
        let url = "\(baseURL)/endpoint/v1/endpoints/\(id)/isolation"
        return try await get(url: url)
    }

    // MARK: - Scan

    func scanEndpoint(id: String) async throws {
        let url = "\(baseURL)/endpoint/v1/endpoints/\(id)/scans"
        try await postEmpty(url: url)
    }

    // MARK: - Cases

    func fetchCases(severity: String? = "high", pageSize: Int = 50) async throws -> CasesResponse {
        var params = ["pageSize": "\(pageSize)"]
        if let severity { params["severities"] = severity }
        let url = buildURL("\(baseURL)/cases/v1/cases", params: params)
        return try await get(url: url)
    }

    func fetchCase(id: String) async throws -> SophosCase {
        let url = "\(baseURL)/cases/v1/cases/\(id)"
        return try await get(url: url)
    }

    // MARK: - HTTP helpers

    private func authorizedRequest(url: String, method: String) async throws -> URLRequest {
        guard let requestURL = URL(string: url) else { throw APIError.invalidURL }
        let token = try await auth.validToken()

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(tenantId, forHTTPHeaderField: "X-Tenant-ID")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func get<T: Decodable>(url: String) async throws -> T {
        var request = try await authorizedRequest(url: url, method: "GET")
        request.setValue(nil, forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    @discardableResult
    private func post<T: Decodable>(url: String, body: [String: Any]) async throws -> T {
        var request = try await authorizedRequest(url: url, method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request)
    }

    private func postEmpty(url: String) async throws {
        var request = try await authorizedRequest(url: url, method: "POST")
        request.httpBody = "{}".data(using: .utf8)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else { throw APIError.requestFailed }
    }

    @discardableResult
    private func patch<T: Decodable>(url: String, body: [String: Any]) async throws -> T {
        var request = try await authorizedRequest(url: url, method: "PATCH")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError
        }

        if http.statusCode == 401 {
            // Token expired mid-session — force refresh and try once more
            _ = try await auth.refreshToken()
            var retried = request
            let newToken = try await auth.validToken()
            retried.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retried)
            guard let retryHttp = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHttp.statusCode)
            else { throw APIError.unauthorized }
            return try decode(retryData)
        }

        guard (200...299).contains(http.statusCode) else {
            if let apiErr = try? JSONDecoder().decode(SophosAPIError.self, from: data),
               let msg = apiErr.message {
                throw APIError.apiError(msg)
            }
            throw APIError.httpError(http.statusCode)
        }

        return try decode(data)
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    private func buildURL(_ base: String, params: [String: String]) -> String {
        guard !params.isEmpty else { return base }
        let query = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        return "\(base)?\(query)"
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case networkError
    case unauthorized
    case requestFailed
    case httpError(Int)
    case apiError(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "Invalid URL."
        case .networkError:             return "Network error. Check your connection."
        case .unauthorized:             return "Session expired. Please sign in again."
        case .requestFailed:            return "Request failed. Please try again."
        case .httpError(let code):      return "Server error \(code)."
        case .apiError(let msg):        return msg
        case .decodingError(let msg):   return "Data error: \(msg)"
        }
    }
}
