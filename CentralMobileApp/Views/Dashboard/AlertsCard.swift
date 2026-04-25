import SwiftUI

struct AlertsCard: View {

    let alerts: [SophosAlert]
    let isLoading: Bool
    var onViewAll: (() -> Void)?

    @State private var datePreset: AlertsDatePreset = .all

    private var filteredAlerts: [SophosAlert] {
        guard let cutoff = datePreset.startDate else { return alerts }
        return alerts.filter { ($0.raisedDate ?? .distantPast) >= cutoff }
    }

    private var highAlerts:   [SophosAlert] { filteredAlerts.filter { $0.severity.lowercased() == "high" } }
    private var mediumAlerts: [SophosAlert] { filteredAlerts.filter { $0.severity.lowercased() == "medium" } }
    private var recentAlerts: [SophosAlert] { Array(filteredAlerts.prefix(3)) }

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

                // Date preset chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SophosTheme.Spacing.xs) {
                        ForEach(AlertsDatePreset.allCases, id: \.self) { preset in
                            FilterPill(
                                label: preset.label,
                                isSelected: datePreset == preset,
                                icon: preset == .all ? nil : "calendar",
                                iconColor: SophosTheme.Colors.sophosBlue
                            ) {
                                datePreset = preset
                            }
                        }
                    }
                }

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
                        count: filteredAlerts.count - highAlerts.count - mediumAlerts.count,
                        label: "Other",
                        color: SophosTheme.Colors.severityInfo
                    )
                    Spacer()
                }

                Divider().background(SophosTheme.Colors.divider)

                if recentAlerts.isEmpty {
                    EmptyStateRow(icon: "checkmark.shield", message: "No alerts in this period")
                } else {
                    // Recent alerts preview (up to 3)
                    ForEach(recentAlerts) { alert in
                        AlertRowMini(alert: alert)
                        if alert.id != recentAlerts.last?.id {
                            Divider().background(SophosTheme.Colors.divider).padding(.leading, 32)
                        }
                    }
                }

                // View All footer — always shown so navigation is always accessible
                Divider().background(SophosTheme.Colors.divider)

                Button {
                    onViewAll?()
                } label: {
                    HStack {
                        if filteredAlerts.count > 3 {
                            Text("View all \(filteredAlerts.count) alerts")
                                .font(SophosTheme.Typography.footnote(.semibold))
                        } else {
                            Text("View all alerts")
                                .font(SophosTheme.Typography.footnote(.semibold))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(SophosTheme.Colors.sophosBlue)
                    .padding(.vertical, SophosTheme.Spacing.xs)
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
                .frame(width: 4)
                .frame(minHeight: 48)

            VStack(alignment: .leading, spacing: 3) {
                // Title
                Text(alert.description ?? alert.type ?? "Security Alert")
                    .font(SophosTheme.Typography.footnote(.semibold))
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                    .lineLimit(1)

                // Severity + product
                HStack(spacing: SophosTheme.Spacing.xs) {
                    SeverityBadge(severity: alert.severity)
                    if let product = alert.product {
                        Text(product)
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                // Date + time (absolute + relative)
                if let date = alert.raisedDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                        Text("·")
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                            .font(SophosTheme.Typography.caption2())
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
