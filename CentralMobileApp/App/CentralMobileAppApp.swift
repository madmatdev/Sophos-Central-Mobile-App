import SwiftUI
import SwiftData
import UserNotifications

@main
struct CentralMobileAppApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    DashboardView()
                        .environment(authViewModel)
                } else {
                    CredentialsView(viewModel: authViewModel)
                }
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            CachedAccountHealth.self,
            CachedAlert.self,
            CachedEndpoint.self,
            CachedCase.self,
            NotificationPreference.self
        ])
    }
}
