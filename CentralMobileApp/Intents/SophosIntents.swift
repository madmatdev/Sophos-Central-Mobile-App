import AppIntents
import Foundation

// MARK: - "Check Health Score" Shortcut

struct CheckHealthIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Sophos Health Score"
    static var description = IntentDescription("Get your Sophos Central account health score.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        if DemoDataService.isDemoMode {
            return .result(dialog: "Your Sophos Central health score is 88 out of 100. Status: Healthy. 2 endpoints have protection issues.")
        }

        let api = SophosAPIService.shared
        let health = try await api.fetchAccountHealth()
        let score = health.endpoint?.protection?.computer?.score ?? 0
        let status = score >= 80 ? "Healthy" : score >= 50 ? "Needs attention" : "Critical"

        return .result(dialog: "Your Sophos Central health score is \(score) out of 100. Status: \(status).")
    }
}

// MARK: - "Check Alerts" Shortcut

struct CheckAlertsIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Sophos Alerts"
    static var description = IntentDescription("Get a summary of current Sophos Central alerts.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        if DemoDataService.isDemoMode {
            return .result(dialog: "You have 6 alerts: 3 high severity including a ransomware detection, 2 medium, and 1 low.")
        }

        let api = SophosAPIService.shared
        let response = try await api.fetchAlerts()
        let alerts = response.items
        let high = alerts.filter { $0.severity.lowercased() == "high" }.count
        let medium = alerts.filter { $0.severity.lowercased() == "medium" }.count
        let low = alerts.filter { $0.severity.lowercased() == "low" }.count

        return .result(dialog: "You have \(alerts.count) alerts: \(high) high, \(medium) medium, \(low) low severity.")
    }
}

// MARK: - "Check Devices" Shortcut

struct CheckDevicesIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Sophos Devices"
    static var description = IntentDescription("Get a summary of endpoint health status.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        if DemoDataService.isDemoMode {
            return .result(dialog: "10 devices managed. 7 healthy, 2 suspicious, 1 in bad health. PACS-IMAGING-1 and FINANCE-WS-03 need attention.")
        }

        let api = SophosAPIService.shared
        let response = try await api.fetchEndpoints()
        let endpoints = response.items
        let healthy = endpoints.filter { $0.health?.overall == "good" }.count
        let bad = endpoints.filter { $0.health?.overall == "bad" }.count
        let suspicious = endpoints.filter { $0.health?.overall == "suspicious" }.count

        return .result(dialog: "\(endpoints.count) devices managed. \(healthy) healthy, \(suspicious) suspicious, \(bad) in bad health.")
    }
}

// MARK: - Shortcuts Provider

struct SophosShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckHealthIntent(),
            phrases: [
                "Check my \(.applicationName) health score",
                "What is my \(.applicationName) health",
                "Get \(.applicationName) health score",
            ],
            shortTitle: "Health Score",
            systemImageName: "heart.text.square"
        )
        AppShortcut(
            intent: CheckAlertsIntent(),
            phrases: [
                "Check \(.applicationName) alerts",
                "How many \(.applicationName) alerts are there",
                "Get \(.applicationName) alert summary",
            ],
            shortTitle: "Alert Summary",
            systemImageName: "bell.badge"
        )
        AppShortcut(
            intent: CheckDevicesIntent(),
            phrases: [
                "Check \(.applicationName) devices",
                "How are my \(.applicationName) devices doing",
                "Get \(.applicationName) device status",
            ],
            shortTitle: "Device Status",
            systemImageName: "laptopcomputer"
        )
    }
}
