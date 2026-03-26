import Foundation
import UserNotifications
import UIKit

final class PushNotificationService: NSObject {

    static let shared = PushNotificationService()
    private override init() { super.init() }

    // MARK: - Registration

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Local notification for new alerts (background fetch)

    func scheduleAlertNotification(for alert: SophosAlert, preference: NotificationPreference) {
        guard shouldNotify(alert: alert, preference: preference) else { return }

        let content = UNMutableNotificationContent()
        content.title = severityTitle(alert.severity)
        content.body = alert.description ?? alert.type ?? "New security alert"
        content.sound = alert.severity.lowercased() == "high" ? .defaultCritical : .default
        content.badge = 1
        content.categoryIdentifier = "SOPHOS_ALERT"
        content.userInfo = [
            "alertId": alert.id,
            "severity": alert.severity,
            "type": alert.type ?? ""
        ]

        let request = UNNotificationRequest(
            identifier: "alert_\(alert.id)",
            content: content,
            trigger: nil       // deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Clear badge

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    // MARK: - Filter logic

    private func shouldNotify(alert: SophosAlert, preference: NotificationPreference) -> Bool {
        // Check severity
        let enabledSeverities = preference.severityList
        guard enabledSeverities.contains(alert.severity.lowercased()) else { return false }

        // Check product filter
        if let product = alert.product?.lowercased() {
            if product.contains("endpoint") && !preference.endpointAlertsEnabled { return false }
            if product.contains("email")    && !preference.emailAlertsEnabled    { return false }
            if product.contains("firewall") && !preference.firewallAlertsEnabled { return false }
        }

        // Check quiet hours
        if preference.quietHoursEnabled {
            let hour = Calendar.current.component(.hour, from: Date())
            let start = preference.quietHoursStart
            let end   = preference.quietHoursEnd
            if start < end {
                if hour >= start && hour < end { return false }
            } else {
                if hour >= start || hour < end { return false }
            }
        }

        return true
    }

    private func severityTitle(_ severity: String) -> String {
        switch severity.lowercased() {
        case "high":   return "Critical Alert"
        case "medium": return "Warning Alert"
        default:       return "Sophos Alert"
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler handler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let alertId = userInfo["alertId"] as? String {
            NotificationCenter.default.post(
                name: .sophosAlertTapped,
                object: nil,
                userInfo: ["alertId": alertId]
            )
        }
        handler()
    }
}

extension Notification.Name {
    static let sophosAlertTapped = Notification.Name("sophosAlertTapped")
    static let sophosDataRefreshed = Notification.Name("sophosDataRefreshed")
}
