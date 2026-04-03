import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var authViewModel = AuthViewModel()
    @State private var showSignOutConfirm = false
    @State private var showNotificationSettings = false

    private let keychain = KeychainService.shared
    private var tenantId:   String { keychain.read(.tenantId) ?? "—" }
    private var dataRegion: String { keychain.read(.dataRegionURL) ?? "—" }

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            List {

                // MARK: - Logo header
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: SophosTheme.Spacing.sm) {
                            SophosLogoView(height: 36, showWordmark: true)
                            Text("Central Mobile")
                                .font(SophosTheme.Typography.footnote())
                                .foregroundColor(SophosTheme.Colors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, SophosTheme.Spacing.md)
                    .listRowBackground(Color.clear)
                }

                // MARK: - Notifications
                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsRow(icon: "bell.badge", label: "Push Notifications", color: SophosTheme.Colors.statusCritical)
                    }
                } header: {
                    Text("Alerts").sophosSectionHeader()
                }
                .listRowBackground(SophosTheme.Colors.backgroundCard)

                // MARK: - Connection
                Section {
                    NavigationLink {
                        TenantManagerView()
                    } label: {
                        SettingsRow(icon: "building.2", label: "Manage Tenants", color: SophosTheme.Colors.sophosBlue)
                    }
                    SettingsInfoRow(label: "Tenant ID",    value: String(tenantId.prefix(12)) + "...")
                    SettingsInfoRow(label: "Data Region",  value: dataRegionShort)
                    SettingsInfoRow(label: "Token Status", value: keychain.isTokenValid ? "Valid" : "Expired")
                } header: {
                    Text("Connection").sophosSectionHeader()
                }
                .listRowBackground(SophosTheme.Colors.backgroundCard)

                // MARK: - AI & Backend
                Section {
                    NavigationLink {
                        AISettingsView()
                    } label: {
                        SettingsRow(icon: "sparkles", label: "AI Configuration", color: SophosTheme.Colors.sophosBlue)
                    }
                    NavigationLink {
                        PlaywrightStatusView()
                    } label: {
                        SettingsRow(icon: "server.rack", label: "Backend Status", color: SophosTheme.Colors.sophosBlue)
                    }
                    NavigationLink {
                        PoliciesView()
                    } label: {
                        SettingsRow(icon: "shield.checkered", label: "Health Check", color: .green)
                    }
                    NavigationLink {
                        ScreenshotView()
                    } label: {
                        SettingsRow(icon: "camera", label: "Live View", color: .purple)
                    }
                    NavigationLink {
                        ExclusionsListView()
                    } label: {
                        SettingsRow(icon: "shield.slash", label: "Exclusions", color: SophosTheme.Colors.statusWarning)
                    }
                    NavigationLink {
                        FirewallListView()
                    } label: {
                        SettingsRow(icon: "flame", label: "Firewalls", color: .orange)
                    }
                    NavigationLink {
                        LiveDiscoverView()
                    } label: {
                        SettingsRow(icon: "magnifyingglass", label: "Live Discover", color: .cyan)
                    }
                    NavigationLink {
                        WatchlistView()
                    } label: {
                        SettingsRow(icon: "eye", label: "Watchlist", color: .indigo)
                    }
                    NavigationLink {
                        ThreatIntelView()
                    } label: {
                        SettingsRow(icon: "shield.checkered", label: "Threat Intel", color: .red)
                    }
                } header: {
                    Text("Advanced").sophosSectionHeader()
                }
                .listRowBackground(SophosTheme.Colors.backgroundCard)

                // MARK: - Cache
                Section {
                    Button {
                        clearCache()
                    } label: {
                        SettingsRow(icon: "trash.circle", label: "Clear Offline Cache", color: SophosTheme.Colors.statusWarning)
                    }
                } header: {
                    Text("Data").sophosSectionHeader()
                }
                .listRowBackground(SophosTheme.Colors.backgroundCard)

                // MARK: - Demo Mode
                Section {
                    Toggle(isOn: Binding(
                        get: { DemoDataService.isDemoMode },
                        set: { DemoDataService.isDemoMode = $0 }
                    )) {
                        SettingsRow(icon: "play.rectangle", label: "Demo Mode", color: .purple)
                    }
                    .tint(SophosTheme.Colors.sophosBlue)
                } header: {
                    Text("Demo").sophosSectionHeader()
                } footer: {
                    Text("Uses realistic fake data for customer demos. No real tenant connection needed.")
                        .font(SophosTheme.Typography.caption2())
                        .foregroundStyle(SophosTheme.Colors.textTertiary)
                }
                .listRowBackground(SophosTheme.Colors.backgroundCard)

                // MARK: - Account
                Section {
                    Button {
                        showSignOutConfirm = true
                    } label: {
                        SettingsRow(icon: "rectangle.portrait.and.arrow.right", label: "Sign Out", color: SophosTheme.Colors.statusCritical)
                    }
                } header: {
                    Text("Account").sophosSectionHeader()
                }
                .listRowBackground(SophosTheme.Colors.backgroundCard)

                // MARK: - About
                Section {
                    SettingsInfoRow(label: "Version",  value: appVersion)
                    SettingsInfoRow(label: "iOS",      value: UIDevice.current.systemVersion)
                } header: {
                    Text("About").sophosSectionHeader()
                }
                .listRowBackground(SophosTheme.Colors.backgroundCard)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(SophosTheme.Colors.backgroundPrimary)
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) { authViewModel.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your credentials will be removed from this device.")
        }
    }

    // MARK: - Helpers

    private var dataRegionShort: String {
        let full = keychain.read(.dataRegionURL) ?? "—"
        return full
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "api-", with: "")
            .components(separatedBy: "/").first ?? full
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func clearCache() {
        do {
            try modelContext.delete(model: CachedAlert.self)
            try modelContext.delete(model: CachedEndpoint.self)
            try modelContext.delete(model: CachedCase.self)
            try modelContext.delete(model: CachedAccountHealth.self)
        } catch {}
    }
}

// MARK: - Settings row components

struct SettingsRow: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(SophosTheme.Typography.body())
                .foregroundColor(SophosTheme.Colors.textPrimary)
        }
    }
}

struct SettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(SophosTheme.Typography.body())
                .foregroundColor(SophosTheme.Colors.textPrimary)
            Spacer()
            Text(value)
                .font(SophosTheme.Typography.body())
                .foregroundColor(SophosTheme.Colors.textSecondary)
        }
    }
}
