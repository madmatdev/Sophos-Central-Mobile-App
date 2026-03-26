import Foundation

actor AuthService {

    static let shared = AuthService()
    private init() {}

    private let tokenURL = URL(string: "https://id.sophos.com/api/v2/oauth2/token")!
    private let whoamiURL = URL(string: "https://api.central.sophos.com/whoami/v1")!
    private let keychain = KeychainService.shared

    // MARK: - Authenticate

    /// Authenticates with client credentials, fetches tenant info, caches everything.
    func authenticate(clientId: String, clientSecret: String) async throws {
        let token = try await fetchToken(clientId: clientId, clientSecret: clientSecret)
        try await fetchWhoami(token: token.accessToken)

        keychain.save(clientId, for: .clientId)
        keychain.save(clientSecret, for: .clientSecret)
        keychain.save(token.accessToken, for: .accessToken)

        let expiry = Date().timeIntervalSince1970 + Double(token.expiresIn)
        keychain.save(String(expiry), for: .tokenExpiry)
    }

    // MARK: - Get valid token (refresh if needed)

    func validToken() async throws -> String {
        if keychain.isTokenValid, let token = keychain.read(.accessToken) {
            return token
        }
        return try await refreshToken()
    }

    // MARK: - Refresh using cached credentials

    @discardableResult
    func refreshToken() async throws -> String {
        guard let clientId = keychain.read(.clientId),
              let clientSecret = keychain.read(.clientSecret)
        else { throw AuthError.noCredentials }

        let tokenResponse = try await fetchToken(clientId: clientId, clientSecret: clientSecret)
        keychain.save(tokenResponse.accessToken, for: .accessToken)

        let expiry = Date().timeIntervalSince1970 + Double(tokenResponse.expiresIn)
        keychain.save(String(expiry), for: .tokenExpiry)

        return tokenResponse.accessToken
    }

    // MARK: - Sign out

    func signOut() {
        keychain.clearAll()
    }

    // MARK: - Private helpers

    private func fetchToken(clientId: String, clientSecret: String) async throws -> TokenResponse {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=client_credentials",
            "client_id=\(clientId.urlEncoded)",
            "client_secret=\(clientSecret.urlEncoded)",
            "scope=token"
        ].joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw AuthError.invalidCredentials
        }

        guard httpResponse.statusCode == 200 else {
            throw AuthError.httpError(httpResponse.statusCode)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        if let errorCode = tokenResponse.errorCode, !errorCode.isEmpty {
            throw AuthError.apiError(tokenResponse.message ?? errorCode)
        }

        return tokenResponse
    }

    private func fetchWhoami(token: String) async throws {
        var request = URLRequest(url: whoamiURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else { throw AuthError.whoamiFailed }

        let whoami = try JSONDecoder().decode(WhoamiResponse.self, from: data)

        keychain.save(whoami.id, for: .tenantId)

        let dataRegion = whoami.apiHosts.dataRegion ?? whoami.apiHosts.global
        keychain.save(dataRegion, for: .dataRegionURL)
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case noCredentials
    case invalidCredentials
    case whoamiFailed
    case networkError
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No credentials found. Please sign in again."
        case .invalidCredentials:
            return "Invalid Client ID or Client Secret. Please check your API credentials."
        case .whoamiFailed:
            return "Could not retrieve tenant information. Please try again."
        case .networkError:
            return "Network error. Please check your connection."
        case .httpError(let code):
            return "Server returned error \(code). Please try again."
        case .apiError(let message):
            return message
        }
    }
}

// MARK: - String URL encoding

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
