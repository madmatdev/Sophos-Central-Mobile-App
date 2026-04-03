import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = PushNotificationService.shared
        // Start smart alert polling
        SmartNotificationService.shared.startPolling()
        return true
    }

    // MARK: - APNs registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[APNs] Device token: \(token)")
        // In production, send this token to your backend push service
        UserDefaults.standard.set(token, forKey: "apns_device_token")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Registration failed: \(error.localizedDescription)")
    }

    // MARK: - Background fetch for alert polling

    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task {
            do {
                let response = try await SophosAPIService.shared.fetchAlerts()
                if response.items.isEmpty {
                    completionHandler(.noData)
                } else {
                    // Fire local notifications for any new high alerts
                    let pref = NotificationPreference()   // default prefs if none stored
                    for alert in response.items where alert.severity.lowercased() == "high" {
                        PushNotificationService.shared.scheduleAlertNotification(for: alert, preference: pref)
                    }
                    completionHandler(.newData)
                }
            } catch {
                completionHandler(.failed)
            }
        }
    }
}
