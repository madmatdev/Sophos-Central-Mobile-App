import SwiftUI

struct DeviceDetailView: View {

    let endpoint: SophosEndpoint
    @Bindable var viewModel: DevicesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showIsolateConfirm    = false
    @State private var showDeIsolateConfirm  = false
    @State private var showScanConfirm       = false
    @State private var isIsolated            = false
    @State private var checkingIsolation     = false

    private let api = SophosAPIService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SophosTheme.Spacing.md) {

                        // Header card
                        deviceHeaderCard

                        // Health status
                        healthCard

                        // System info
                        systemInfoCard

                        // User info
                        if endpoint.associatedPerson?.name != nil {
                            userCard
                        }

                        // Network
                        if !(endpoint.ipv4Addresses?.isEmpty ?? true) {
                            networkCard
                        }

                        // Actions
                        actionsCard

                        // Feedback
                        if let success = viewModel.actionSuccess {
                            feedbackBanner(message: success, isError: false)
                        }
                        if let error = viewModel.actionError {
                            feedbackBanner(message: error, isError: true)
                        }

                        Spacer().frame(height: SophosTheme.Spacing.xl)
                    }
                    .padding(SophosTheme.Spacing.md)
                }
            }
            .navigationTitle(endpoint.hostname ?? "Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(SophosTheme.Colors.sophosBlue)
                }
            }
            // Isolate confirmation
            .confirmationDialog(
                "Isolate \(endpoint.hostname ?? "this device")?",
                isPresented: $showIsolateConfirm,
                titleVisibility: .visible
            ) {
                Button("Isolate Device", role: .destructive) {
                    Task {
                        let success = await viewModel.isolateEndpoint(endpoint)
                        if success { isIsolated = true }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the device from the network. Use Face ID or Touch ID to confirm.")
            }
            // De-isolate confirmation
            .confirmationDialog(
                "Remove isolation from \(endpoint.hostname ?? "this device")?",
                isPresented: $showDeIsolateConfirm,
                titleVisibility: .visible
            ) {
                Button("Remove Isolation") {
                    Task {
                        let success = await viewModel.deIsolateEndpoint(endpoint)
                        if success { isIsolated = false }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The device will be reconnected to the network.")
            }
            // Scan confirmation
            .confirmationDialog(
                "Scan \(endpoint.hostname ?? "this device")?",
                isPresented: $showScanConfirm,
                titleVisibility: .visible
            ) {
                Button("Start Scan") {
                    Task { await viewModel.scanEndpoint(endpoint) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A full security scan will be initiated on this device. Use Face ID or Touch ID to confirm.")
            }
        }
    }

    // MARK: - Sub-views

    private var deviceHeaderCard: some View {
        HStack(spacing: SophosTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: SophosTheme.Radius.sm)
                    .fill(SophosTheme.Colors.backgroundCard2)
                    .frame(width: 56, height: 56)
                Image(systemName: endpoint.platformIcon)
                    .font(.system(size: 28))
                    .foregroundColor(SophosTheme.Colors.sophosBlue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(endpoint.hostname ?? "Unknown")
                    .font(SophosTheme.Typography.title3(.semibold))
                    .foregroundColor(SophosTheme.Colors.textPrimary)

                HStack(spacing: SophosTheme.Spacing.xs) {
                    HealthStatusDot(status: endpoint.health?.overall ?? "unknown")
                    if let online = endpoint.online {
                        Label(online ? "Online" : "Offline",
                              systemImage: online ? "wifi" : "wifi.slash")
                            .font(SophosTheme.Typography.caption2(.semibold))
                            .foregroundColor(online
                                ? SophosTheme.Colors.statusHealthy
                                : SophosTheme.Colors.textTertiary)
                    }
                    if isIsolated {
                        Label("Isolated", systemImage: "network.slash")
                            .font(SophosTheme.Typography.caption2(.semibold))
                            .foregroundColor(SophosTheme.Colors.statusCritical)
                    }
                }

                if let lastSeen = endpoint.lastSeenDate {
                    Text("Last seen \(lastSeen, style: .relative) ago")
                        .font(SophosTheme.Typography.caption())
                        .foregroundColor(SophosTheme.Colors.textTertiary)
                }
            }
            Spacer()
        }
        .padding(SophosTheme.Spacing.md)
        .sophosCard()
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.xs) {
            Text("Health Status")
                .sophosSectionHeader()
                .padding(.bottom, SophosTheme.Spacing.xxs)

            if let health = endpoint.health {
                DetailRow(label: "Overall",   value: health.overall.capitalized)
                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                if let threats = health.threats?.status {
                    DetailRow(label: "Threats",   value: threats.capitalized)
                    Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                }
                if let services = health.services?.status {
                    DetailRow(label: "Services",  value: services.capitalized)
                }
            }
        }
        .padding(SophosTheme.Spacing.md)
        .sophosCard()
    }

    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.xs) {
            Text("System")
                .sophosSectionHeader()
                .padding(.bottom, SophosTheme.Spacing.xxs)

            if let os = endpoint.os {
                if let name = os.name {
                    DetailRow(label: "OS", value: name)
                    Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                }
                if let platform = os.platform {
                    DetailRow(label: "Platform", value: platform.capitalized)
                    Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                }
                DetailRow(label: "Type", value: os.isServer == true ? "Server" : "Workstation")
            }
            Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
            DetailRow(
                label: "Tamper Prot.",
                value: endpoint.tamperProtectionEnabled == true ? "Enabled" : "Disabled"
            )
            DetailRow(label: "Device ID", value: String(endpoint.id.prefix(8)) + "...")
        }
        .padding(SophosTheme.Spacing.md)
        .sophosCard()
    }

    private var userCard: some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.xs) {
            Text("Associated User")
                .sophosSectionHeader()
                .padding(.bottom, SophosTheme.Spacing.xxs)

            if let person = endpoint.associatedPerson {
                if let name = person.name {
                    DetailRow(label: "Name", value: name)
                    Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                }
                if let login = person.viaLogin {
                    DetailRow(label: "Login", value: login)
                }
            }
        }
        .padding(SophosTheme.Spacing.md)
        .sophosCard()
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.xs) {
            Text("Network")
                .sophosSectionHeader()
                .padding(.bottom, SophosTheme.Spacing.xxs)

            ForEach(Array((endpoint.ipv4Addresses ?? []).enumerated()), id: \.offset) { idx, ip in
                DetailRow(label: "IPv4 \(idx + 1)", value: ip)
                if idx < (endpoint.ipv4Addresses?.count ?? 1) - 1 {
                    Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                }
            }
        }
        .padding(SophosTheme.Spacing.md)
        .sophosCard()
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.sm) {
            Text("Actions")
                .sophosSectionHeader()

            let isActing = viewModel.actionInProgress == endpoint.id

            // Isolate / De-isolate
            if isIsolated {
                ActionButton(
                    label: "Remove Isolation",
                    icon: "network",
                    color: SophosTheme.Colors.statusHealthy,
                    isLoading: isActing
                ) { showDeIsolateConfirm = true }
            } else {
                ActionButton(
                    label: "Isolate Endpoint",
                    icon: "network.slash",
                    color: SophosTheme.Colors.statusCritical,
                    isLoading: isActing
                ) { showIsolateConfirm = true }
            }

            // Scan
            ActionButton(
                label: "Run Security Scan",
                icon: "magnifyingglass.circle",
                color: SophosTheme.Colors.sophosBlue,
                isLoading: isActing
            ) { showScanConfirm = true }
        }
        .padding(SophosTheme.Spacing.md)
        .sophosCard()
    }

    private func feedbackBanner(message: String, isError: Bool) -> some View {
        HStack(spacing: SophosTheme.Spacing.xs) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? SophosTheme.Colors.statusCritical : SophosTheme.Colors.statusHealthy)
            Text(message)
                .font(SophosTheme.Typography.footnote())
                .foregroundColor(isError ? SophosTheme.Colors.statusCritical : SophosTheme.Colors.statusHealthy)
        }
        .padding(SophosTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isError ? SophosTheme.Colors.statusCritical : SophosTheme.Colors.statusHealthy).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
    }
}

// MARK: - Action button

struct ActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView().tint(color).scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                        .foregroundColor(color)
                }
                Text(label)
                    .font(SophosTheme.Typography.subheadline(.semibold))
                    .foregroundColor(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(SophosTheme.Colors.textTertiary)
            }
            .padding(SophosTheme.Spacing.sm)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
        }
        .disabled(isLoading)
    }
}
