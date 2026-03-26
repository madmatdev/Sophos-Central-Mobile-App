import SwiftUI

struct AlertsCard: View {

    let alerts: [SophosAlert]
    let isLoading: Bool
    var onViewAll: (() -> Void)?

    private var highAlerts:   [SophosAlert] { alerts.filter { $0.severity.lowercased() == "high" } }
    private var mediumAlerts: [SophosAlert] { alerts.filter { $0.severity.lowercased() == "medium" } }
    private var recentAlerts: [SophosAlert] { Array(alerts.prefix(3)) }

    var body: some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.md) {

            // Header
            HStack {
                Label("Alerts", systemImage: "bell.badge")
                    .font(SophosTheme.Typography.headline())
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                Spacer()
                if isLoading {
                    ProgressView().tint(SophosTheme.Colors.sophosBlue).scaleEffect(0.8)
                } else if !alerts.isEmpty {
                    Button("View All") { onViewAll?() }
                        .font(SophosTheme.Typography.footnote(.semibold))
                        .foregroundColor(SophosTheme.Colors.sophosBlue)
                }
            }

            if isLoading {
                SkeletonRow()
                SkeletonRow()
            } else if alerts.isEmpty {
                EmptyStateRow(icon: "checkmark.shield", message: "No active alerts")
            } else {
                // Summary counts
                HStack(spacing: SophosTheme.Spacing.md) {
                    AlertCountBadge(
                        count: highAlerts.count,
                        label: "Critical",
                        color: SophosTheme.Colors.severityHigh
                    )
                    AlertCountBadge(
                        count: mediumAlerts.count,
                        label: "Warning",
                        color: SophosTheme.Colors.severityMedium
                    )
                    AlertCountBadge(
                        count: alerts.count - highAlerts.count - mediumAlerts.count,
                        label: "Other",
                        color: SophosTheme.Colors.severityInfo
                    )
                    Spacer()
                }

                Divider().background(SophosTheme.Colors.divider)

                // Recent alerts preview
                ForEach(recentAlerts) { alert in
                    AlertRowMini(alert: alert)
                    if alert.id != recentAlerts.last?.id {
                        Divider().background(SophosTheme.Colors.divider).padding(.leading, 32)
                    }
                }

                if alerts.count > 3 {
                    Button {
                        onViewAll?()
                    } label: {
                        Text("+\(alerts.count - 3) more alerts")
                            .font(SophosTheme.Typography.footnote())
                            .foregroundColor(SophosTheme.Colors.sophosBlue)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .padding(SophosTheme.Spacing.md)
        .sophosCard()
    }
}

// MARK: - Alert count badge

struct AlertCountBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(SophosTheme.Typography.title2(.semibold))
                .foregroundColor(count > 0 ? color : SophosTheme.Colors.textTertiary)
            Text(label)
                .font(SophosTheme.Typography.caption2())
                .foregroundColor(SophosTheme.Colors.textSecondary)
        }
        .frame(minWidth: 60)
        .padding(.vertical, SophosTheme.Spacing.xs)
        .background(count > 0 ? color.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
    }
}

// MARK: - Alert row mini

struct AlertRowMini: View {
    let alert: SophosAlert

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(SophosTheme.Colors.severityColor(alert.severity))
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.description ?? alert.type ?? "Security Alert")
                    .font(SophosTheme.Typography.footnote(.semibold))
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: SophosTheme.Spacing.xs) {
                    SeverityBadge(severity: alert.severity)
                    if let product = alert.product {
                        Text(product)
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                    }
                    Spacer()
                    if let date = alert.raisedDate {
                        Text(date, style: .relative)
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Severity badge

struct SeverityBadge: View {
    let severity: String

    var color: Color { SophosTheme.Colors.severityColor(severity) }

    var body: some View {
        Text(severity.capitalized)
            .font(SophosTheme.Typography.caption2(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
