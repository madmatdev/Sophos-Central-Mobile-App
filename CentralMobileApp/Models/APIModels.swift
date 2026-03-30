import Foundation

// MARK: - Auth / Token

struct TokenResponse: Codable {
    let accessToken: String?   // nil when Sophos returns a pure error body
    let tokenType: String?
    let expiresIn: Int?
    let refreshToken: String?
    let errorCode: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case tokenType    = "token_type"
        case expiresIn    = "expires_in"
        case refreshToken = "refresh_token"
        case errorCode    = "errorCode"
        case message      = "message"
    }
}

// MARK: - Whoami

struct WhoamiResponse: Codable {
    let id: String
    let idType: String
    let apiHosts: APIHosts

    struct APIHosts: Codable {
        let global: String
        let dataRegion: String?
    }
}

// MARK: - Account Health

struct AccountHealthResponse: Codable {
    let overall: HealthScore
    let endpoint: HealthScore?
    let server: HealthScore?
    let firewall: HealthScore?
    let email: HealthScore?

    struct HealthScore: Codable {
        let score: Int?
        let status: String          // "good" | "fair" | "bad"
        let checks: [HealthCheck]?
    }

    struct HealthCheck: Codable, Identifiable {
        let id: String
        let title: String
        let status: String
        let description: String?
        let snoozed: Bool?
    }
}

// MARK: - Alerts

struct AlertsResponse: Codable {
    let items: [SophosAlert]
    let pages: Pages?
}

struct SophosAlert: Codable, Identifiable {
    let id: String
    let description: String?
    let type: String?
    let groupKey: String?
    let severity: String           // "high" | "medium" | "low" | "info"
    let category: String?
    let product: String?
    let tenant: TenantRef?
    let managedAgent: ManagedAgentRef?
    let person: PersonRef?
    let raisedAt: String?
    let allowedActions: [String]?

    struct TenantRef: Codable {
        let id: String
        let name: String?
    }

    struct ManagedAgentRef: Codable {
        let id: String?
        let type: String?
    }

    struct PersonRef: Codable {
        let id: String?
        let name: String?
    }

    var raisedDate: Date? {
        guard let str = raisedAt else { return nil }
        return ISO8601DateFormatter().date(from: str)
    }
}

// MARK: - Endpoints / Devices

struct EndpointsResponse: Codable {
    let items: [SophosEndpoint]
    let pages: Pages?
}

struct SophosEndpoint: Codable, Identifiable {
    let id: String
    let type: String?
    let tenant: TenantRef?
    let hostname: String?
    let health: EndpointHealth?
    let os: OperatingSystem?
    let ipv4Addresses: [String]?
    let ipv6Addresses: [String]?
    let macAddresses: [String]?
    let associatedPerson: AssociatedPerson?
    let assignedProducts: [AssignedProduct]?
    let lastSeenAt: String?
    let tamperProtectionEnabled: Bool?

    struct TenantRef: Codable {
        let id: String
        let name: String?
    }

    struct EndpointHealth: Codable {
        let overall: String        // "good" | "suspicious" | "bad" | "unknown"
        let threats: ThreatHealth?
        let services: ServiceHealth?

        struct ThreatHealth: Codable {
            let status: String
        }

        struct ServiceHealth: Codable {
            let status: String
            let serviceDetails: [ServiceDetail]?

            struct ServiceDetail: Codable {
                let name: String?
                let status: String?
            }
        }
    }

    struct OperatingSystem: Codable {
        let isServer: Bool?
        let platform: String?      // "windows" | "macOS" | "linux"
        let name: String?
        let majorVersion: Int?
        let minorVersion: Int?
        let build: Int?
    }

    struct AssociatedPerson: Codable {
        let id: String?
        let name: String?
        let viaLogin: String?
    }

    struct AssignedProduct: Codable {
        let code: String?
        let version: String?
        let status: String?
    }

    var lastSeenDate: Date? {
        guard let str = lastSeenAt else { return nil }
        return ISO8601DateFormatter().date(from: str)
    }

    var platformIcon: String {
        switch os?.platform?.lowercased() {
        case "windows": return "desktopcomputer"
        case "macos":   return "laptopcomputer"
        case "linux":   return "terminal"
        default:        return "display"
        }
    }
}

// MARK: - Isolation

struct IsolationRequest: Codable {
    let enabled: Bool
    let comment: String?
}

struct IsolationResponse: Codable {
    let id: String?
    let enabled: Bool?
    let lastEnabledAt: String?
    let lastEnabledBy: PersonRef?
    let lastDisabledAt: String?
    let lastDisabledBy: PersonRef?

    struct PersonRef: Codable {
        let id: String?
        let name: String?
    }
}

// MARK: - Scan

struct ScanRequest: Codable {
    // POST body is empty for triggering a default scan
}

struct ScanResponse: Codable {
    let id: String?
    let status: String?
    let requestedAt: String?
}

// MARK: - Cases

struct CasesResponse: Codable {
    let items: [SophosCase]
    let pages: Pages?
}

struct SophosCase: Codable, Identifiable {
    let id: String
    let tenant: TenantRef?
    let assignee: Assignee?
    let type: String?              // "investigation"
    let name: String?
    let severity: String           // "high" | "medium" | "low" | "info"
    let status: String             // "open" | "inProgress" | "closed"
    let managedBy: String?         // "self" | "sophos"
    let overview: String?
    let detectionCount: Int?
    let createdAt: String?
    let updatedAt: String?

    struct TenantRef: Codable {
        let id: String
        let name: String?
    }

    struct Assignee: Codable {
        let id: String?
        let name: String?
    }

    var createdDate: Date? {
        guard let str = createdAt else { return nil }
        return ISO8601DateFormatter().date(from: str)
    }

    var updatedDate: Date? {
        guard let str = updatedAt else { return nil }
        return ISO8601DateFormatter().date(from: str)
    }

    var statusDisplay: String {
        switch status.lowercased() {
        case "inprogress", "in_progress": return "In Progress"
        case "open":                      return "Open"
        case "closed":                    return "Closed"
        default:                          return status.capitalized
        }
    }
}

// MARK: - Shared

struct Pages: Codable {
    let current: Int?
    let size: Int?
    let total: Int?
    let items: Int?
    let nextKey: String?
}

struct PersonRef: Codable {
    let id: String?
    let name: String?
}

// MARK: - API Error

struct SophosAPIError: Codable, Error {
    let error: String?
    let message: String?
    let correlationId: String?
    let code: String?
    let requestId: String?
    let createdAt: String?
}

struct EmptyResponse: Decodable {}
