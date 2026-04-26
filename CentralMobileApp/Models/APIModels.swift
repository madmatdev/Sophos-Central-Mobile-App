import Foundation

// MARK: - Date parsing

/// Parses ISO 8601 strings from the Sophos API, handling both fractional-seconds
/// (e.g. "2024-04-25T10:30:00.000Z") and whole-second (e.g. "2024-04-25T10:30:00Z") forms.
private func parseISO8601(_ str: String) -> Date? {
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fmt.date(from: str) { return date }
    fmt.formatOptions = [.withInternetDateTime]
    return fmt.date(from: str)
}

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

// MARK: - Directory Users

struct UsersResponse: Codable {
    let items: [SophosUser]
    let pages: Pages?
}

struct SophosUser: Codable, Identifiable {
    let id: String
    let name: String?
    let firstName: String?
    let lastName: String?
    let email: String?
    let exchangeLogin: String?   // alternate email field
    let viaLogin: String?        // login identifier
    let groups: [UserGroupRef]?
    let source: String?          // e.g. "AD", "AzureAD", "Sophos"
    let sourceType: String?      // e.g. "activeDirectory", "azureActiveDirectory"
    let createdAt: String?

    struct UserGroupRef: Codable {
        let id: String?
        let name: String?
    }

    var displayName: String {
        if let n = name, !n.isEmpty { return n }
        let full = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        return full.isEmpty ? (viaLogin ?? email ?? "Unknown User") : full
    }

    var primaryEmail: String? {
        email ?? exchangeLogin ?? viaLogin
    }

    var initials: String {
        let words = displayName.split(separator: " ")
        let first = words.first?.prefix(1) ?? ""
        let last  = words.count > 1 ? (words.last?.prefix(1) ?? "") : ""
        let result = "\(first)\(last)".uppercased()
        return result.isEmpty ? "?" : result
    }

    var sourceLabel: String {
        switch (sourceType ?? source ?? "").lowercased() {
        case let s where s.contains("azure"):  return "Azure AD"
        case let s where s.contains("active"): return "Active Directory"
        case let s where s.contains("sophos"): return "Sophos"
        case let s where s.contains("google"): return "Google"
        default:
            let raw = source ?? sourceType ?? ""
            return raw.isEmpty ? "Local" : raw
        }
    }

    var sourceIcon: String {
        switch (sourceType ?? source ?? "").lowercased() {
        case let s where s.contains("azure"):  return "cloud"
        case let s where s.contains("active"): return "server.rack"
        case let s where s.contains("sophos"): return "shield"
        case let s where s.contains("google"): return "globe"
        default: return "person.circle"
        }
    }

    var createdDate: Date? {
        guard let str = createdAt else { return nil }
        return parseISO8601(str)
    }
}

// User group memberships (from /directory/users/{id}/groups)
struct UserGroupMembershipsResponse: Codable {
    let items: [UserGroupMembership]
    let pages: Pages?
}

struct UserGroupMembership: Codable, Identifiable {
    let id: String
    let name: String?
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
        return parseISO8601(str)
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
        return parseISO8601(str)
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

// MARK: - Tamper Protection

struct TamperProtectionResponse: Codable {
    let enabled: Bool
    let password: String?
    let previousPasswords: [String]?
}

// MARK: - Detections

struct DetectionCountsResponse: Codable {
    let resolutionDetectionCounts: [ResolutionDetectionCount]?

    struct ResolutionDetectionCount: Codable {
        let totalCount: Int?
        let countBySeverity: CountBySeverity?
    }

    struct CountBySeverity: Codable {
        let critical: Int?
        let high: Int?
        let medium: Int?
        let low: Int?
        let info: Int?
    }

    /// Totals summed across all hourly buckets
    var totalCount: Int    { resolutionDetectionCounts?.compactMap { $0.totalCount }.reduce(0, +) ?? 0 }
    var critical:   Int    { resolutionDetectionCounts?.compactMap { $0.countBySeverity?.critical }.reduce(0, +) ?? 0 }
    var high:       Int    { resolutionDetectionCounts?.compactMap { $0.countBySeverity?.high }.reduce(0, +) ?? 0 }
    var medium:     Int    { resolutionDetectionCounts?.compactMap { $0.countBySeverity?.medium }.reduce(0, +) ?? 0 }
    var low:        Int    { resolutionDetectionCounts?.compactMap { $0.countBySeverity?.low }.reduce(0, +) ?? 0 }
    var info:       Int    { resolutionDetectionCounts?.compactMap { $0.countBySeverity?.info }.reduce(0, +) ?? 0 }
}

struct DetectionQueryRun: Codable {
    let id: String
    let createdAt: String?
    let result: String?   // "notAvailable" | "succeeded" | "failed"
    let status: String?   // "pending" | "finished"

    var isFinished: Bool { status?.lowercased() == "finished" }
    var succeeded:  Bool { result?.lowercased() == "succeeded" }
}

struct DetectionResultsPage: Codable {
    let items: [SophosDetection]
}

struct SophosDetection: Codable, Identifiable {
    let id: String
    let type: String?
    let attackType: String?
    let severity: Int?
    let count: Int?
    let detectionRule: String?
    let detectionRuleDescription: String?
    let detectionAttack: String?
    let sensorGeneratedAt: String?
    let sensor: Sensor?
    let device: DetectionDevice?
    let mitreAttacks: [MitreAttack]?

    struct Sensor: Codable {
        let id: String?
        let type: String?
        let version: String?
    }

    struct DetectionDevice: Codable {
        let id: String?
        let type: String?
        let entity: String?  // hostname
    }

    struct MitreAttack: Codable {
        let tactic: Tactic?
        struct Tactic: Codable {
            let id: String?
            let name: String?
        }
    }

    var generatedDate: Date? {
        guard let str = sensorGeneratedAt else { return nil }
        return parseISO8601(str)
    }

    var severityLabel: String {
        switch severity ?? 0 {
        case 9...10: return "Critical"
        case 7...8:  return "High"
        case 4...6:  return "Medium"
        case 1...3:  return "Low"
        default:     return "Info"
        }
    }

    var mitreTactics: [String] {
        mitreAttacks?.compactMap { $0.tactic?.name } ?? []
    }
}

// MARK: - Adaptive Attack Protection

struct AdaptiveAttackProtectionResponse: Codable {
    let desiredState: DesiredState?
    let actualState: ActualState?

    struct DesiredState: Codable {
        let enabled: Bool?
        let source: String?       // "user" | "automatic"
        let expiresAfter: String? // ISO 8601 duration e.g. "P7D"
    }

    struct ActualState: Codable {
        let enabled: Bool?
        let lastUpdatedAt: String?
        let expiresAt: String?    // ISO 8601 datetime

        var expiryDate: Date? {
            guard let str = expiresAt else { return nil }
            return parseISO8601(str)
        }
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

struct SophosCase: Codable, Identifiable, Equatable {
    let id: String
    let tenant: TenantRef?
    let assignee: Assignee?
    let type: String?
    let name: String?
    /// API values: "notSet" | "critical" | "high" | "medium" | "low" | "informational"
    let severity: String
    /// API values: "new" | "investigating" | "onHold" | "resolved" | "actionRequired"
    let status: String
    /// "self" | "sophos"
    let managedBy: String?
    let overview: String?
    let detectionCount: Int?
    let createdAt: String?
    let updatedAt: String?

    struct TenantRef: Codable, Equatable {
        let id: String
        let name: String?
    }

    struct Assignee: Codable, Equatable {
        let id: String?
        let name: String?
    }

    var createdDate: Date? {
        guard let str = createdAt else { return nil }
        return parseISO8601(str)
    }

    var updatedDate: Date? {
        guard let str = updatedAt else { return nil }
        return parseISO8601(str)
    }

    /// Human-readable status label
    var statusDisplay: String {
        switch status {
        case "new":            return "New"
        case "investigating":  return "Investigating"
        case "onHold":         return "On Hold"
        case "resolved":       return "Resolved"
        case "actionRequired": return "Action Required"
        default:               return status.capitalized
        }
    }

    /// True only for self-managed cases that can be updated via API
    var isSelfManaged: Bool { managedBy?.lowercased() == "self" }
    var isResolved: Bool    { status == "resolved" }
}

// MARK: - Case update request

struct UpdateCaseRequest: Encodable {
    var status: String?
    var severity: String?
    var name: String?
    var overview: String?
}

// MARK: - Case Detections

struct CaseDetectionsResponse: Codable {
    let items: [CaseDetection]
    let pages: Pages?
}

struct CaseDetection: Codable, Identifiable {
    let id: String
    // Type / name fields — Sophos uses several naming conventions
    let type: String?
    let detectionType: String?
    let attackType: String?
    let detectionRule: String?
    let detectionRuleDescription: String?
    // Severity is an integer 1-10 (same schema as SophosDetection)
    let severity: Int?
    // Timestamp field names vary across API versions
    let sensorGeneratedAt: String?
    let detectedAt: String?
    let createdAt: String?
    let device: CaseDetectionDevice?
    let mitreAttacks: [CaseDetectionMitreAttack]?

    struct CaseDetectionDevice: Codable {
        let id: String?
        let entity: String?    // Sophos detections use "entity" for hostname
        let hostname: String?  // fallback
        let type: String?
    }

    struct CaseDetectionMitreAttack: Codable {
        let tactic: Tactic?
        let technique: Technique?

        struct Tactic: Codable {
            let id: String?
            let name: String?
        }

        struct Technique: Codable {
            let id: String?
            let name: String?
        }
    }

    // Best available timestamp across field name variants
    var detectedDate: Date? {
        let str = sensorGeneratedAt ?? detectedAt ?? createdAt
        guard let str else { return nil }
        return parseISO8601(str)
    }

    // Best available device label
    var deviceName: String? { device?.entity ?? device?.hostname }

    // Best available display name
    var displayName: String {
        detectionRule ?? attackType ?? detectionType ?? type ?? "Unknown Detection"
    }

    // Convert integer severity → string token used by SeverityBadge / severityColor
    var severityToken: String {
        switch severity ?? 0 {
        case 9...10: return "critical"
        case 7...8:  return "high"
        case 4...6:  return "medium"
        case 1...3:  return "low"
        default:     return "informational"
        }
    }

    var mitreTacticNames: [String] {
        mitreAttacks?.compactMap { $0.tactic?.name } ?? []
    }
}

// MARK: - Case MITRE ATT&CK Summary

struct CaseMitreAttackSummary: Codable {
    let tactics: [Tactic]?

    struct Tactic: Codable, Identifiable {
        var id: String { tacticId ?? name ?? UUID().uuidString }
        let tacticId: String?
        let name: String?
        let techniques: [Technique]?

        // API may use "id" key — support both
        enum CodingKeys: String, CodingKey {
            case tacticId = "id"
            case name
            case techniques
        }
    }

    struct Technique: Codable, Identifiable {
        var id: String { techniqueId ?? name ?? UUID().uuidString }
        let techniqueId: String?
        let name: String?
        let count: Int?
        let subTechniques: [SubTechnique]?

        enum CodingKeys: String, CodingKey {
            case techniqueId = "id"
            case name
            case count
            case subTechniques
        }
    }

    struct SubTechnique: Codable, Identifiable {
        var id: String { subTechniqueId ?? name ?? UUID().uuidString }
        let subTechniqueId: String?
        let name: String?
        let count: Int?

        enum CodingKeys: String, CodingKey {
            case subTechniqueId = "id"
            case name
            case count
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
