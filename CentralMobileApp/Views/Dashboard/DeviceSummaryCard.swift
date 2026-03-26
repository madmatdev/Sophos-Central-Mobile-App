import SwiftUI

struct DeviceSummaryCard: View {

    let endpoints: [SophosEndpoint]
    let isLoading: Bool
    var onViewAll: (() -> Void)?

    private var healthy:    Int { endpoints.filter { $0.health?.overall.lowercased() == "good" }.count }
    private var suspicious: Int { endpoints.filter { $0.health?.overall.lowercased() == "suspicious" }.count }
    private var bad:        Int { endpoints.filter { $0.health?.overall.lowercased() == "bad" }.count }
    private var total:      Int { endpoints.count }
    private var servers:    Int { endpoints.filter { $0.os?.isServer == true }.count }
    private var workstations: Int { total - servers }

    var body: some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.md) {

            // Header
            HStack {
                Label("Devices & Users", systemImage: "laptopcomputer.and.iphone")
                    .font(SophosTheme.Typography.headline())
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                Spacer()
                if isLoading {
                    ProgressView().tint(SophosTheme.Colors.sophosBlue).scaleEffect(0.8)
                } else if !endpoints.isEmpty {
                    Button("View All") { onViewAll?() }
                        .font(SophosTheme.Typography.footnote(.semibold))
                        .foregroundColor(SophosTheme.Colors.sophosBlue)
                }
            }

            if isLoading {
                SkeletonRow()
                SkeletonRow()
            } else if endpoints.isEmpty {
                EmptyStateRow(icon: "display.trianglebadge.exclamationmark", message: "No devices found")
            } else {

                // Health bar
                DeviceHealthBar(healthy: healthy, suspicious: suspicious, bad: bad, total: total)

                // Stat row
                HStack(spacing: SophosTheme.Spacing.md) {
                    DeviceStatCell(value: total, label: "Total", color: SophosTheme.Colors.sophosBlue)
                    DeviceStatCell(value: healthy, label: "Healthy", color: SophosTheme.Colors.statusHealthy)
                    DeviceStatCell(value: suspicious + bad, label: "At Risk", color: suspicious + bad > 0 ? SophosTheme.Colors.statusCritical : SophosTheme.Colors.textTertiary)
                    DeviceStatCell(value: servers, label: "Servers", color: SophosTheme.Colors.textSecondary)
                }

                Divider().background(SophosTheme.Colors.divider)

                // At-risk devices preview (up to 3)
                let atRisk = endpoints
                    .filter { ["bad","suspicious"].contains($0.health?.overall.lowercased() ?? "") }
                    .prefix(3)

                if atRisk.isEmpty {
                    HStack(spacing: SophosTheme.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(SophosTheme.Colors.statusHealthy)
                        Text("All devices healthy")
                            .font(SophosTheme.Typography.footnote())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                    }
                } else {
                    VStack(spacing: SophosTheme.Spacing.xs) {
                        Text("At Risk")
                            .sophosSectionHeader()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(Array(atRisk)) { endpoint in
                            DeviceRowMini(endpoint: endpoint)
                        }
                    }
                }
            }
        }
        .padding(SophosTheme.Spacing.md)
        .sophosCard()
    }
}

// MARK: - Health bar

struct DeviceHealthBar: View {
    let healthy: Int
    let suspicious: Int
    let bad: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                if healthy > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SophosTheme.Colors.statusHealthy)
                        .frame(width: barWidth(geo.size.width, count: healthy))
                }
                if suspicious > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SophosTheme.Colors.statusWarning)
                        .frame(width: barWidth(geo.size.width, count: suspicious))
                }
                if bad > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SophosTheme.Colors.statusCritical)
                        .frame(width: barWidth(geo.size.width, count: bad))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
        }
        .frame(height: 6)
    }

    private func barWidth(_ total: CGFloat, count: Int) -> CGFloat {
        guard self.total > 0 else { return 0 }
        return (total - 4) * CGFloat(count) / CGFloat(self.total)
    }
}

// MARK: - Stat cell

struct DeviceStatCell: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(SophosTheme.Typography.title3(.semibold))
                .foregroundColor(color)
            Text(label)
                .font(SophosTheme.Typography.caption2())
                .foregroundColor(SophosTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Device row mini

struct DeviceRowMini: View {
    let endpoint: SophosEndpoint

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {
            Image(systemName: endpoint.platformIcon)
                .font(.system(size: 16))
                .foregroundColor(SophosTheme.Colors.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(endpoint.hostname ?? "Unknown")
                    .font(SophosTheme.Typography.footnote(.semibold))
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                    .lineLimit(1)
                if let person = endpoint.associatedPerson?.name {
                    Text(person)
                        .font(SophosTheme.Typography.caption2())
                        .foregroundColor(SophosTheme.Colors.textSecondary)
                }
            }
            Spacer()
            HealthStatusDot(status: endpoint.health?.overall ?? "unknown")
        }
    }
}

// MARK: - Health status dot

struct HealthStatusDot: View {
    let status: String

    var color: Color { SophosTheme.Colors.healthColor(status) }

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(statusLabel)
                .font(SophosTheme.Typography.caption2())
                .foregroundColor(color)
        }
    }

    private var statusLabel: String {
        switch status.lowercased() {
        case "good":        return "Healthy"
        case "suspicious":  return "Suspicious"
        case "bad":         return "At Risk"
        default:            return "Unknown"
        }
    }
}
