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

    /// POST /common/v1/alerts/search — server-side filtered alert fetch.
    /// Replaces the GET /alerts approach: severity is now applied by the server,
    /// so callers get up to `pageSize` alerts *per severity* instead of 100 total.
    func searchAlerts(
        pageSize: Int = 100,
        severities: [String] = [],
        from: Date? = nil,
        to: Date? = nil
    ) async throws -> AlertsResponse {
        let url = "\(baseURL)/common/v1/alerts/search"
        let iso = ISO8601DateFormatter()
        var body: [String: Any] = [
            "pageSize": pageSize,
            "orderBy":  "raisedAt:desc"
        ]
        if !severities.isEmpty { body["severities"] = severities }
        if let from { body["from"] = iso.string(from: from) }
        if let to   { body["to"]   = iso.string(from: to) }
        return try await post(url: url, body: body)
    }

    func acknowledgeAlert(alertId: String) async throws {
        try await performAlertAction(alertId: alertId, action: "acknowledge",
                                     message: "Acknowledged via Sophos Central Mobile")
    }

    func clearThreat(alertId: String) async throws {
        try await performAlertAction(alertId: alertId, action: "clearThreat")
    }

    func cleanVirus(alertId: String) async throws {
        try await performAlertAction(alertId: alertId, action: "cleanVirus")
    }

    func cleanPua(alertId: String) async throws {
        try await performAlertAction(alertId: alertId, action: "cleanPua")
    }

    private func performAlertAction(alertId: String, action: String, message: String? = nil) async throws {
        let url = "\(baseURL)/common/v1/alerts/\(alertId)/actions"
        var body: [String: Any] = ["action": action]
        if let message { body["message"] = message }
        let _: EmptyResponse = try await post(url: url, body: body)
    }

    /// Bulk-acknowledge multiple alerts concurrently. Returns the IDs that succeeded.
    func acknowledgeAlerts(alertIds: [String]) async -> [String] {
        await withTaskGroup(of: String?.self) { group in
            for id in alertIds {
                group.addTask {
                    do {
                        try await self.acknowledgeAlert(alertId: id)
                        return id
                    } catch {
                        return nil
                    }
                }
            }
            var succeeded: [String] = []
            for await result in group {
                if let id = result { succeeded.append(id) }
            }
            return succeeded
        }
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

    func isolateEndpoint(id: String, comment: String? = nil) async throws {
        let url = "\(baseURL)/endpoint/v1/endpoints/isolation"
        let body: [String: Any] = [
            "enabled": true,
            "ids": [id],
            "comment": comment ?? "Isolated via Sophos Central Mobile"
        ]
        let _: EmptyResponse = try await post(url: url, body: body)
    }

    func deIsolateEndpoint(id: String) async throws {
        let url = "\(baseURL)/endpoint/v1/endpoints/isolation"
        let body: [String: Any] = [
            "enabled": false,
            "ids": [id]
        ]
        let _: EmptyResponse = try await post(url: url, body: body)
    }

    func fetchIsolationStatus(id: String) async throws -> IsolationResponse {
        let url = "\(baseURL)/endpoint/v1/endpoints/\(id)/isolation"
        return try await get(url: url)
    }

    // MARK: - Tamper Protection

    func setTamperProtection(id: String, enabled: Bool) async throws -> TamperProtectionResponse {
        let url = "\(baseURL)/endpoint/v1/endpoints/\(id)/tamper-protection"
        let body: [String: Any] = ["enabled": enabled]
        return try await post(url: url, body: body)
    }

    // MARK: - Detections

    func fetchDetectionCounts() async throws -> DetectionCountsResponse {
        let url = buildURL("\(baseURL)/detections/v1/queries/detections/counts", params: ["resolution": "hour"])
        return try await get(url: url)
    }

    func startDetectionQuery(from: Date? = nil, to: Date? = nil) async throws -> DetectionQueryRun {
        let url = "\(baseURL)/detections/v1/queries/detections"
        let iso = ISO8601DateFormatter()
        var body: [String: Any] = [
            "sort": [["field": "sensorGeneratedAt", "direction": "desc"]]
        ]
        if let from { body["from"] = iso.string(from: from) }
        if let to   { body["to"]   = iso.string(from: to) }
        return try await post(url: url, body: body)
    }

    func pollDetectionQuery(runId: String) async throws -> DetectionQueryRun {
        let url = "\(baseURL)/detections/v1/queries/detections/\(runId)"
        return try await get(url: url)
    }

    func fetchDetectionResults(runId: String, pageSize: Int = 50) async throws -> DetectionResultsPage {
        let url = buildURL(
            "\(baseURL)/detections/v1/queries/detections/\(runId)/results",
            params: ["page": "1", "pageSize": "\(pageSize)"]
        )
        return try await get(url: url)
    }

    /// Convenience: start query, poll until finished, return results. Max 15 polls × 2s = 30s.
    func fetchDetections(from: Date? = nil, to: Date? = nil, pageSize: Int = 50) async throws -> [SophosDetection] {
        let run = try await startDetectionQuery(from: from, to: to)
        var polled = run
        var attempts = 0
        while !polled.isFinished && attempts < 15 {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            polled = try await pollDetectionQuery(runId: run.id)
            attempts += 1
        }
        guard polled.succeeded else { throw APIError.requestFailed }
        let page = try await fetchDetectionResults(runId: run.id, pageSize: pageSize)
        return page.items
    }

    // MARK: - Adaptive Attack Protection

    func fetchAdaptiveAttackProtection(id: String) async throws -> AdaptiveAttackProtectionResponse {
        let url = "\(baseURL)/endpoint/v1/endpoints/\(id)/adaptive-attack-protection"
        return try await get(url: url)
    }

    func setAdaptiveAttackProtection(id: String, enabled: Bool, expiresAfter: String? = "P7D") async throws -> AdaptiveAttackProtectionResponse {
        let url = "\(baseURL)/endpoint/v1/endpoints/\(id)/adaptive-attack-protection"
        var body: [String: Any] = ["enabled": enabled]
        if enabled, let expiry = expiresAfter { body["expiresAfter"] = expiry }
        return try await post(url: url, body: body)
    }

    // MARK: - Scan

    func scanEndpoint(id: String) async throws {
        let url = "\(baseURL)/endpoint/v1/endpoints/\(id)/scans"
        try await postEmpty(url: url)
    }

    // MARK: - Cases

    func fetchCases(statuses: [String] = [], severities: [String] = [], pageSize: Int = 50) async throws -> CasesResponse {
        // Build URL manually to support repeated query params (status=new&status=investigating…)
        var components = URLComponents(string: "\(baseURL)/cases/v1/cases")!
        var items: [URLQueryItem] = [URLQueryItem(name: "pageSize", value: "\(pageSize)")]
        for s in statuses   { items.append(URLQueryItem(name: "status",   value: s)) }
        for s in severities { items.append(URLQueryItem(name: "severity", value: s)) }
        components.queryItems = items
        let url = components.url?.absoluteString ?? "\(baseURL)/cases/v1/cases"
        #if DEBUG
        print("📋 fetchCases URL: \(url)")
        #endif
        return try await get(url: url)
    }

    func fetchCase(id: String) async throws -> SophosCase {
        let url = "\(baseURL)/cases/v1/cases/\(id)"
        return try await get(url: url)
    }

    func updateCase(id: String, request: UpdateCaseRequest) async throws -> SophosCase {
        let url = "\(baseURL)/cases/v1/cases/\(id)"
        // Only send non-nil fields — build the patch body manually
        var body: [String: Any] = [:]
        if let v = request.status   { body["status"]   = v }
        if let v = request.severity { body["severity"] = v }
        if let v = request.name     { body["name"]     = v }
        if let v = request.overview { body["overview"] = v }
        return try await patch(url: url, body: body)
    }

    // MARK: - Directory Users

    func fetchUsers(pageSize: Int = 100) async throws -> UsersResponse {
        let url = buildURL("\(baseURL)/common/v1/directory/users",
                           params: ["pageSize": "\(pageSize)"])
        return try await get(url: url)
    }

    func fetchUser(id: String) async throws -> SophosUser {
        let url = "\(baseURL)/common/v1/directory/users/\(id)"
        return try await get(url: url)
    }

    func fetchUserGroups(userId: String) async throws -> UserGroupMembershipsResponse {
        let url = "\(baseURL)/common/v1/directory/users/\(userId)/groups"
        return try await get(url: url)
    }

    func fetchCaseDetections(caseId: String, pageSize: Int = 50) async throws -> CaseDetectionsResponse {
        let url = buildURL("\(baseURL)/cases/v1/cases/\(caseId)/detections",
                           params: ["pageSize": "\(pageSize)"])
        return try await get(url: url)
    }

    func fetchCaseMitreAttackSummary(caseId: String) async throws -> CaseMitreAttackSummary {
        let url = "\(baseURL)/cases/v1/cases/\(caseId)/mitre-attack-summary"
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
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError
        }

        #if DEBUG
        print("▶️ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "unknown") → HTTP \(http.statusCode)")
        if !(200...299).contains(http.statusCode),
           let body = String(data: data, encoding: .utf8) {
            print("❌ Error body: \(body)")
        }
        #endif

        guard (200...299).contains(http.statusCode) else {
            let errDecoder = JSONDecoder()
            errDecoder.keyDecodingStrategy = .convertFromSnakeCase
            if let apiErr = try? errDecoder.decode(SophosAPIError.self, from: data) {
                let msg = apiErr.message ?? apiErr.error ?? "HTTP \(http.statusCode)"
                throw APIError.apiError(msg)
            }
            throw APIError.httpError(http.statusCode)
        }
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

        #if DEBUG
        let urlStr = request.url?.absoluteString ?? "unknown"
        print("▶️ \(request.httpMethod ?? "?") \(urlStr) → HTTP \(http.statusCode)")
        if !(200...299).contains(http.statusCode),
           let body = String(data: data, encoding: .utf8) {
            print("❌ Error body: \(body)")
        }
        // Temporary: log raw response for directory/users to diagnose decode issues
        if urlStr.contains("directory/users"),
           let raw = String(data: data, encoding: .utf8) {
            let preview = raw.prefix(2000)
            print("📋 directory/users raw response:\n\(preview)")
        }
        #endif

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
            // Use the same snake_case decoder so fields like "correlation_id" map correctly
            let errDecoder = JSONDecoder()
            errDecoder.keyDecodingStrategy = .convertFromSnakeCase
            if let apiErr = try? errDecoder.decode(SophosAPIError.self, from: data) {
                let msg = apiErr.message ?? apiErr.error ?? "HTTP \(http.statusCode)"
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
            #if DEBUG
            print("❌ Decode error for \(T.self): \(error)")
            if let raw = String(data: data, encoding: .utf8) {
                print("📄 Raw response body:\n\(raw)")
            }
            #endif
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
        case .httpError(let code):
            switch code {
            case 403: return "Access denied (403). Ensure your API credentials include directory/user permissions."
            case 404: return "Endpoint not found (404). This feature may not be available for your account."
            case 429: return "Too many requests (429). Please wait a moment and try again."
            default:  return "Server error \(code)."
            }
        case .apiError(let msg):        return msg
        case .decodingError(let msg):   return "Data error: \(msg)"
        }
    }
}
