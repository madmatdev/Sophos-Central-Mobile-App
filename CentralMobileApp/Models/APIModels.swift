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

    let tenant: TenantInfo?
    let endpoint: EndpointHealth?
    let networkDevice: NetworkDeviceHealth?

    // MARK: Tenant

    struct TenantInfo: Codable {
        let id: String
        let name: String?
    }

    // MARK: Endpoint

    struct EndpointHealth: Codable {
        let protection: ProtectionHealth?
        let policy: PolicyHealth?
        let exclusions: ExclusionsHealth?
        let tamperProtection: TamperProtectionHealth?
    }

    // --- Protection ---

    struct ProtectionHealth: Codable {
        let computer: SoftwareCheck?
        let server: SoftwareCheck?
    }

    struct SoftwareCheck: Codable {
        let score: Int?
        let total: Int?
        let notFullyProtected: Int?
        let snoozed: Bool?
        let snoozeDetail: SnoozeDetail?
    }

    // --- Policy ---
    // Keys under computer/server use hyphens ("threat-protection",
    // "server-threat-protection") so we decode them as dictionaries.

    struct PolicyHealth: Codable {
        let computer: [String: PolicyCheck]?
        let server: [String: PolicyCheck]?

        var computerThreatProtection: PolicyCheck? { computer?["threat-protection"] }
        var serverThreatProtection: PolicyCheck?   { server?["server-threat-protection"] }
    }

    struct PolicyCheck: Codable {
        let score: Int?
        let total: Int?
        let notOnRecommended: Int?
        let snoozed: Bool?
        let snoozeDetail: SnoozeDetail?
    }

    // --- Exclusions ---

    struct ExclusionsHealth: Codable {
        let policy: PolicyExclusionsHealth?
        let global: GlobalExclusionsCheck?
    }

    struct PolicyExclusionsHealth: Codable {
        let computer: PolicyExclusionsCheck?
        let server: PolicyExclusionsCheck?
    }

    struct PolicyExclusionsCheck: Codable {
        let score: Int?
        let total: Int?
        let numberOfSecurityRisks: Int?
        let snoozed: Bool?
        let snoozeDetail: SnoozeDetail?
    }

    struct GlobalExclusionsCheck: Codable {
        let score: Int?
        let numberOfSecurityRisks: Int?
        let lockedByManagingAccount: Bool?
        let snoozed: Bool?
        let snoozeDetail: SnoozeDetail?
    }

    // --- Tamper Protection ---

    struct TamperProtectionHealth: Codable {
        let computer: TamperCheck?
        let server: TamperCheck?
        let globalDetail: GlobalTamperCheck?
    }

    struct TamperCheck: Codable {
        let score: Int?
        let total: Int?
        let disabled: Int?
        let snoozed: Bool?
        let snoozeDetail: SnoozeDetail?
    }

    struct GlobalTamperCheck: Codable {
        let score: Int?
        let enabled: Bool?
        let snoozed: Bool?
        let snoozeDetail: SnoozeDetail?
    }

    // --- Network / Firewall ---

    struct NetworkDeviceHealth: Codable {
        let firewall: FirewallHealth?
    }

    struct FirewallHealth: Codable {
        let firewallAutomaticBackup: BackupCheck?
    }

    struct BackupCheck: Codable {
        let score: Int?
        let total: Int?
        let notOnRecommended: Int?
        let snoozed: Bool?
        let snoozeDetail: SnoozeDetail?
    }

    // --- Snooze ---

    struct SnoozeDetail: Codable {
        let start: String?
        let end: String?
        let expiry: String?
        let expired: Bool?
        let comment: String?
    }

    // MARK: Computed helpers (used by the widget)

    /// Average of all available check scores (0–100).
    var computedScore: Int {
        var scores: [Int] = []
        if let s = endpoint?.protection?.computer?.score      { scores.append(s) }
        if let s = endpoint?.protection?.server?.score        { scores.append(s) }
        if let s = endpoint?.policy?.computerThreatProtection?.score { scores.append(s) }
        if let s = endpoint?.policy?.serverThreatProtection?.score   { scores.append(s) }
        if let s = endpoint?.exclusions?.policy?.computer?.score     { scores.append(s) }
        if let s = endpoint?.exclusions?.policy?.server?.score       { scores.append(s) }
        if let s = endpoint?.exclusions?.global?.score               { scores.append(s) }
        if let s = endpoint?.tamperProtection?.computer?.score       { scores.append(s) }
        if let s = endpoint?.tamperProtection?.server?.score         { scores.append(s) }
        if let s = endpoint?.tamperProtection?.globalDetail?.score   { scores.append(s) }
        if let s = networkDevice?.firewall?.firewallAutomaticBackup?.score { scores.append(s) }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / scores.count
    }

    /// Derived status label from computedScore.
    var overallStatus: String {
        let s = computedScore
        if s >= 80 { return "good" }
        if s >= 50 { return "fair" }
        return "bad"
    }

    /// Total endpoints not fully protected.
    var protectionIssues: Int {
        (endpoint?.protection?.computer?.notFullyProtected ?? 0) +
        (endpoint?.protection?.server?.notFullyProtected   ?? 0)
    }

    var protectionTotal: Int {
        (endpoint?.protection?.computer?.total ?? 0) +
        (endpoint?.protection?.server?.total   ?? 0)
    }

    /// Policies not on recommended settings.
    var policyIssues: Int {
        (endpoint?.policy?.computerThreatProtection?.notOnRecommended ?? 0) +
        (endpoint?.policy?.serverThreatProtection?.notOnRecommended   ?? 0)
    }

    var policyTotal: Int {
        (endpoint?.policy?.computerThreatProtection?.total ?? 0) +
        (endpoint?.policy?.serverThreatProtection?.total   ?? 0)
    }

    /// Risky exclusions across policy and global.
    var exclusionRisks: Int {
        (endpoint?.exclusions?.policy?.computer?.numberOfSecurityRisks ?? 0) +
        (endpoint?.exclusions?.policy?.server?.numberOfSecurityRisks   ?? 0) +
        (endpoint?.exclusions?.global?.numberOfSecurityRisks           ?? 0)
    }

    /// Endpoints with tamper protection disabled, plus global-off flag.
    var tamperIssues: Int {
        let comp   = endpoint?.tamperProtection?.computer?.disabled ?? 0
        let srv    = endpoint?.tamperProtection?.server?.disabled   ?? 0
        let global = endpoint?.tamperProtection?.globalDetail?.enabled == false ? 1 : 0
        return comp + srv + global
    }

    var tamperTotal: Int {
        (endpoint?.tamperProtection?.computer?.total ?? 0) +
        (endpoint?.tamperProtection?.server?.total   ?? 0)
    }

    var anyCheckSnoozed: Bool {
        endpoint?.protection?.computer?.snoozed == true ||
        endpoint?.protection?.server?.snoozed == true ||
        endpoint?.tamperProtection?.computer?.snoozed == true ||
        endpoint?.tamperProtection?.server?.snoozed == true ||
        endpoint?.tamperProtection?.globalDetail?.snoozed == true ||
        endpoint?.exclusions?.global?.snoozed == true
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
    let online: Bool?

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
