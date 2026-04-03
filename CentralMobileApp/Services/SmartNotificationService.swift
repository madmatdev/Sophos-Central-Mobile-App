import Foundation
import UserNotifications
import UIKit

/// Polls Sophos Central for new alerts and sends smart notifications
/// with AI-generated triage summaries.
final class SmartNotificationService {

    static let shared = SmartNotificationService()
    private init() {}

    private let api = SophosAPIService.shared
    private let agent = AIAgentService.shared
    private let keychain = KeychainService.shared
    private var lastAlertId: String?
    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 60 // 1 minute

    // MARK: - Start/Stop

    func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { await self?.checkForNewAlerts() }
        }
        // Also check immediately
        Task { await checkForNewAlerts() }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Check for new alerts

    private func checkForNewAlerts() async {
        // Skip in demo mode
        guard !DemoDataService.isDemoMode else { return }
        guard keychain.hasCredentials else { return }

        do {
            let response = try await api.fetchAlerts(pageSize: 5, severity: "high")
            let alerts = response.items

            guard let newest = alerts.first else { return }

            // Skip if we've already seen this alert
            if newest.id == lastAlertId { return }
            let isFirstRun = lastAlertId == nil
            lastAlertId = newest.id

            // Don't notify on first run (avoid spamming on app launch)
            if isFirstRun { return }

            // Count new high alerts
            let highCount = alerts.filter { $0.severity.lowercased() == "high" }.count

            // Build notification
            let title = "🔴 \(highCount) High Alert\(highCount > 1 ? "s" : "")"
            let body = newest.description ?? "New high-severity alert detected"

            // Try AI triage if API key is set
            var triageText: String?
            if keychain.read(.groqAPIKey) != nil {
                let alertSummary = alerts.prefix(3).map { "[\($0.severity)] \($0.description ?? "?")" }.joined(separator: "\n")
                triageText = try? await agent.chat(
                    userMessage: "Briefly triage these new alerts in 2 sentences: \(alertSummary)",
                    history: [],
                    environmentContext: ""
                )
            }

            // Send notification
            await sendNotification(
                title: title,
                body: triageText ?? body,
                alertId: newest.id,
                category: "ALERT_HIGH"
            )
        } catch {
            // Silently fail — don't spam on network errors
        }
    }

    // MARK: - Send notification

    private func sendNotification(title: String, body: String, alertId: String, category: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = ["alertId": alertId]
        content.interruptionLevel = .timeSensitive

        // Add quick actions
        let acknowledgeAction = UNNotificationAction(
            identifier: "ACKNOWLEDGE",
            title: "Acknowledge",
            options: [.authenticationRequired]
        )
        let viewAction = UNNotificationAction(
            identifier: "VIEW",
            title: "View Details",
            options: [.foreground]
        )
        let isolateAction = UNNotificationAction(
            identifier: "ISOLATE",
            title: "Isolate Endpoint",
            options: [.authenticationRequired, .destructive]
        )

        let alertCategory = UNNotificationCategory(
            identifier: "ALERT_HIGH",
            actions: [acknowledgeAction, viewAction, isolateAction],
            intentIdentifiers: [],
            options: []
        )

        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([alertCategory])

        let request = UNNotificationRequest(
            identifier: "alert-\(alertId)",
            content: content,
            trigger: nil // Immediate
        )

        try? await center.add(request)
    }

    // MARK: - Handle notification response

    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let alertId = response.notification.request.content.userInfo["alertId"] as? String ?? ""

        switch response.actionIdentifier {
        case "ACKNOWLEDGE":
            try? await api.acknowledgeAlert(alertId: alertId)
        case "ISOLATE":
            // Would need endpoint ID — for now just acknowledge
            try? await api.acknowledgeAlert(alertId: alertId)
        case "VIEW":
            // App will open to alert detail — handled by AppDelegate
            break
        default:
            break
        }
    }
}
