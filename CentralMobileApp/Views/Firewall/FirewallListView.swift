import SwiftUI

struct FirewallListView: View {
    @State private var firewalls: [SophosFirewall] = []
    @State private var loading = false
    @State private var error: String?

    private let api = SophosAPIService.shared

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            Group {
                if loading && firewalls.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error, firewalls.isEmpty {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else if firewalls.isEmpty {
                    ContentUnavailableView("No Firewalls", systemImage: "flame",
                        description: Text("No Sophos Firewalls linked to this tenant."))
                } else {
                    List(firewalls) { fw in
                        FirewallRow(firewall: fw)
                            .listRowBackground(SophosTheme.Colors.backgroundCard)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Firewalls")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadFirewalls() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(loading)
            }
        }
        .task { await loadFirewalls() }
    }

    private func loadFirewalls() async {
        loading = true
        error = nil
        do {
            let response = try await api.fetchFirewalls()
            firewalls = response.items
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - Firewall Row

struct FirewallRow: View {
    let firewall: SophosFirewall

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {
            // Status indicator
            Circle()
                .fill(firewall.status?.connected == true ? SophosTheme.Colors.statusHealthy : SophosTheme.Colors.statusCritical)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(firewall.name ?? firewall.hostname ?? "Unknown Firewall")
                    .font(SophosTheme.Typography.body(.semibold))
                    .foregroundStyle(SophosTheme.Colors.textPrimary)

                HStack(spacing: SophosTheme.Spacing.sm) {
                    if let serial = firewall.serialNumber {
                        Text(serial)
                            .font(SophosTheme.Typography.caption2())
                            .foregroundStyle(SophosTheme.Colors.textSecondary)
                    }
                    if let fw = firewall.firmwareVersion {
                        Text("v\(fw)")
                            .font(SophosTheme.Typography.caption2())
                            .foregroundStyle(SophosTheme.Colors.textTertiary)
                    }
                }

                if let lastSeen = firewall.lastSeen {
                    Text("Last seen: \(lastSeen)")
                        .font(SophosTheme.Typography.caption2())
                        .foregroundStyle(SophosTheme.Colors.textTertiary)
                }
            }

            Spacer()

            // Connection badge
            Text(firewall.status?.connected == true ? "Online" : "Offline")
                .font(SophosTheme.Typography.caption2(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (firewall.status?.connected == true ? SophosTheme.Colors.statusHealthy : SophosTheme.Colors.statusCritical)
                        .opacity(0.15)
                )
                .foregroundStyle(firewall.status?.connected == true ? SophosTheme.Colors.statusHealthy : SophosTheme.Colors.statusCritical)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}
