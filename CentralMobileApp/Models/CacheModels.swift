import Foundation
import SwiftData

// MARK: - Cached Account Health

@Model
final class CachedAccountHealth {
    @Attribute(.unique) var id: String = "singleton"
    // Serialised AccountHealthResponse — source of truth for the widget
    var responseJSON: Data?
    // Legacy columns kept to avoid migration failures on existing installs
    var overallStatus: String
    var overallScore: Int
    var lastUpdated: Date

    init(from response: AccountHealthResponse) {
        self.id = "singleton"
        self.responseJSON = try? JSONEncoder().encode(response)
        self.overallStatus = response.overallStatus
        self.overallScore  = response.computedScore
        self.lastUpdated   = Date()
    }

    func decoded() -> AccountHealthResponse? {
        guard let data = responseJSON else { return nil }
        return try? JSONDecoder().decode(AccountHealthResponse.self, from: data)
    }
}

// MARK: - Cached Alert

@Model
final class CachedAlert {
    @Attribute(.unique) var id: String
    var alertDescription: String?
    var type: String?
    var severity: String
    var category: String?
    var product: String?
    var raisedAt: Date?
    var agentId: String?
    var agentType: String?
    var personName: String?
    var allowedActionsJSON: Data?
    var lastUpdated: Date

    init(from alert: SophosAlert) {
        self.id = alert.id
        self.alertDescription = alert.description
        self.type = alert.type
        self.severity = alert.severity
        self.category = alert.category
        self.product = alert.product
        self.raisedAt = alert.raisedDate
        self.agentId = alert.managedAgent?.id
        self.agentType = alert.managedAgent?.type
        self.personName = alert.person?.name
        self.allowedActionsJSON = try? JSONEncoder().encode(alert.allowedActions)
        self.lastUpdated = Date()
    }

    var allowedActions: [String] {
        guard let data = allowedActionsJSON else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

// MARK: - Cached Endpoint

@Model
final class CachedEndpoint {
    @Attribute(.unique) var id: String
    var type: String?
    var hostname: String?
    var healthOverall: String?
    var healthThreats: String?
    var healthServices: String?
    var osIsServer: Bool
    var osPlatform: String?
    var osName: String?
    var osMajorVersion: Int?
    var ipv4AddressesJSON: Data?
    var associatedPersonName: String?
    var associatedPersonLogin: String?
    var lastSeenAt: Date?
    var tamperProtectionEnabled: Bool
    var isIsolated: Bool
    var isOnline: Bool?
    var lastUpdated: Date

    init(from endpoint: SophosEndpoint) {
        self.id = endpoint.id
        self.type = endpoint.type
        self.hostname = endpoint.hostname
        self.healthOverall = endpoint.health?.overall
        self.healthThreats = endpoint.health?.threats?.status
        self.healthServices = endpoint.health?.services?.status
        self.osIsServer = endpoint.os?.isServer ?? false
        self.osPlatform = endpoint.os?.platform
        self.osName = endpoint.os?.name
        self.osMajorVersion = endpoint.os?.majorVersion
        self.ipv4AddressesJSON = try? JSONEncoder().encode(endpoint.ipv4Addresses)
        self.associatedPersonName = endpoint.associatedPerson?.name
        self.associatedPersonLogin = endpoint.associatedPerson?.viaLogin
        self.lastSeenAt = endpoint.lastSeenDate
        self.tamperProtectionEnabled = endpoint.tamperProtectionEnabled ?? false
        self.isIsolated = false
        self.isOnline = endpoint.online
        self.lastUpdated = Date()
    }

    var ipv4Addresses: [String] {
        guard let data = ipv4AddressesJSON else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    var platformIcon: String {
        switch osPlatform?.lowercased() {
        case "windows": return "desktopcomputer"
        case "macos":   return "laptopcomputer"
        case "linux":   return "terminal"
        default:        return "display"
        }
    }
}

// MARK: - Cached Case

@Model
final class CachedCase {
    @Attribute(.unique) var id: String
    var name: String?
    var type: String?
    var severity: String
    var status: String
    var managedBy: String?
    var overview: String?
    var detectionCount: Int
    var assigneeName: String?
    var createdAt: Date?
    var updatedAt: Date?
    var lastUpdated: Date

    init(from sophosCase: SophosCase) {
        self.id = sophosCase.id
        self.name = sophosCase.name
        self.type = sophosCase.type
        self.severity = sophosCase.severity
        self.status = sophosCase.status
        self.managedBy = sophosCase.managedBy
        self.overview = sophosCase.overview
        self.detectionCount = sophosCase.detectionCount ?? 0
        self.assigneeName = sophosCase.assignee?.name
        self.createdAt = sophosCase.createdDate
        self.updatedAt = sophosCase.updatedDate
        self.lastUpdated = Date()
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

// MARK: - Notification Preference

@Model
final class NotificationPreference {
    @Attribute(.unique) var id: String = "singleton"
    var enabledSeverities: String   // Comma-separated: "high,medium"
    var enabledCategories: String   // Comma-separated or "all"
    var quietHoursEnabled: Bool
    var quietHoursStart: Int        // Hour (0-23)
    var quietHoursEnd: Int          // Hour (0-23)
    var endpointAlertsEnabled: Bool
    var emailAlertsEnabled: Bool
    var firewallAlertsEnabled: Bool

    init() {
        self.id = "singleton"
        self.enabledSeverities = "high,medium"
        self.enabledCategories = "all"
        self.quietHoursEnabled = false
        self.quietHoursStart = 22
        self.quietHoursEnd = 7
        self.endpointAlertsEnabled = true
        self.emailAlertsEnabled = true
        self.firewallAlertsEnabled = true
    }

    var severityList: [String] {
        get { enabledSeverities.split(separator: ",").map { String($0) } }
        set { enabledSeverities = newValue.joined(separator: ",") }
    }
}
