import Foundation
import Security

final class KeychainService {

    static let shared = KeychainService()
    private init() {}

    private let service = "com.sophos.central.mobile"

    enum Key: String {
        case clientId       = "sophos_client_id"
        case clientSecret   = "sophos_client_secret"
        case accessToken    = "sophos_access_token"
        case tokenExpiry    = "sophos_token_expiry"
        case tenantId       = "sophos_tenant_id"
        case dataRegionURL  = "sophos_data_region_url"
        case playwrightURL  = "playwright_backend_url"
        case playwrightSecret = "playwright_secret"
        case groqAPIKey     = "groq_api_key"
    }

    // MARK: - Save

    @discardableResult
    func save(_ value: String, for key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Read

    func read(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key.rawValue,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }

        return string
    }

    // MARK: - Delete

    @discardableResult
    func delete(_ key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    // MARK: - Clear all

    func clearAll() {
        Key.allCases.forEach { delete($0) }
    }

    // MARK: - Convenience

    var hasCredentials: Bool {
        read(.clientId) != nil && read(.clientSecret) != nil
    }

    var isTokenValid: Bool {
        guard let token = read(.accessToken),
              !token.isEmpty,
              let expiryStr = read(.tokenExpiry),
              let expiryInterval = TimeInterval(expiryStr)
        else { return false }
        return Date().timeIntervalSince1970 < expiryInterval - 60
    }
}

extension KeychainService.Key: CaseIterable {}
