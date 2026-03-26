import SwiftUI
import SwiftData

struct DashboardView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()
    @State private var selectedTab: DashboardTab = .dashboard

    // Navigation state
    @State private var showAlerts   = false
    @State private var showDevices  = false
    @State private var showCases    = false

    var body: some View {
        TabView(selection: $selectedTab) {

            // MARK: - Dashboard Tab
            NavigationStack {
                dashboardContent
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            SophosLogoView(height: 28, showWordmark: true)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                Task { await viewModel.refreshAll(modelContext: modelContext) }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(SophosTheme.Colors.sophosBlue)
                            }
                            .disabled(viewModel.isLoading)
                        }
                    }
            }
            .tabItem {
                Label("Dashboard", systemImage: "square.grid.2x2")
            }
            .tag(DashboardTab.dashboard)

            // MARK: - Alerts Tab
            NavigationStack {
                AlertsListView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Alerts")
                                .font(SophosTheme.Typography.headline())
                                .foregroundColor(SophosTheme.Colors.textPrimary)
                        }
                    }
            }
            .tabItem {
                Label("Alerts", systemImage: "bell.badge")
            }
            .badge(viewModel.criticalAlertCount > 0 ? "\(viewModel.criticalAlertCount)" : nil)
            .tag(DashboardTab.alerts)

            // MARK: - Devices Tab
            NavigationStack {
                DevicesListView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Devices")
                                .font(SophosTheme.Typography.headline())
                                .foregroundColor(SophosTheme.Colors.textPrimary)
                        }
                    }
            }
            .tabItem {
                Label("Devices", systemImage: "laptopcomputer")
            }
            .tag(DashboardTab.devices)

            // MARK: - Cases Tab
            NavigationStack {
                CasesListView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Cases")
                                .font(SophosTheme.Typography.headline())
                                .foregroundColor(SophosTheme.Colors.textPrimary)
                        }
                    }
            }
            .tabItem {
                Label("Cases", systemImage: "exclamationmark.shield")
            }
            .tag(DashboardTab.cases)

            // MARK: - Settings Tab
            NavigationStack {
                SettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Settings")
                                .font(SophosTheme.Typography.headline())
                                .foregroundColor(SophosTheme.Colors.textPrimary)
                        }
                    }
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(DashboardTab.settings)
        }
        .tint(SophosTheme.Colors.sophosBlue)
        .onAppear {
            configureTabBar()
            Task { await viewModel.refreshAll(modelContext: modelContext) }
        }
    }

    // MARK: - Dashboard content

    private var dashboardContent: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: SophosTheme.Spacing.md) {

                    // Last refreshed
                    if let date = viewModel.lastRefreshed {
                        HStack {
                            Spacer()
                            Text("Updated \(date, style: .relative) ago")
                                .font(SophosTheme.Typography.caption2())
                                .foregroundColor(SophosTheme.Colors.textTertiary)
                        }
                        .padding(.horizontal, SophosTheme.Spacing.md)
                    }

                    // Account Health
                    AccountHealthCard(
                        health: viewModel.accountHealth,
                        isLoading: viewModel.isLoadingHealth
                    )
                    .padding(.horizontal, SophosTheme.Spacing.md)

                    // Alerts
                    AlertsCard(
                        alerts: viewModel.alerts,
                        isLoading: viewModel.isLoadingAlerts,
                        onViewAll: { selectedTab = .alerts }
                    )
                    .padding(.horizontal, SophosTheme.Spacing.md)

                    // Devices
                    DeviceSummaryCard(
                        endpoints: viewModel.endpoints,
                        isLoading: viewModel.isLoadingEndpoints,
                        onViewAll: { selectedTab = .devices }
                    )
                    .padding(.horizontal, SophosTheme.Spacing.md)

                    // Cases
                    HighPriorityCasesCard(
                        cases: viewModel.cases,
                        isLoading: viewModel.isLoadingCases,
                        onViewAll: { selectedTab = .cases }
                    )
                    .padding(.horizontal, SophosTheme.Spacing.md)

                    Spacer().frame(height: SophosTheme.Spacing.xl)
                }
                .padding(.top, SophosTheme.Spacing.sm)
            }
            .refreshable {
                await viewModel.refreshAll(modelContext: modelContext)
            }
        }
    }

    // MARK: - Tab bar appearance

    private func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(SophosTheme.Colors.tabBar)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(SophosTheme.Colors.navigationBar)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }
}

enum DashboardTab: Int {
    case dashboard, alerts, devices, cases, settings
}

// MARK: - Shared skeleton/empty state components

struct SkeletonRow: View {
    @State private var opacity: Double = 0.4

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(SophosTheme.Colors.backgroundCard2)
            .frame(height: 16)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 0.8
                }
            }
    }
}

struct EmptyStateRow: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(SophosTheme.Colors.statusHealthy)
            Text(message)
                .font(SophosTheme.Typography.footnote())
                .foregroundColor(SophosTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
