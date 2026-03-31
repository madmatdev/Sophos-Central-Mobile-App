import SwiftUI

struct AccountHealthCard: View {

    let health: AccountHealthResponse?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.md) {

            // Header
            HStack {
                Label("Account Health", systemImage: "shield.checkered")
                    .font(SophosTheme.Typography.headline())
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                Spacer()
                if isLoading {
                    ProgressView().tint(SophosTheme.Colors.sophosBlue).scaleEffect(0.8)
                }
            }

            if let health {
                scoreRow(health)
                Divider().background(SophosTheme.Colors.divider)
                checksGrid(health)
            } else if !isLoading {
                EmptyStateRow(icon: "shield.slash", message: "Health data unavailable")
            } else {
                SkeletonRow()
                SkeletonRow()
                SkeletonRow()
            }
        }
        .padding(SophosTheme.Spacing.md)
        .sophosCard()
    }

    // MARK: - Score row

    private func scoreRow(_ health: AccountHealthResponse) -> some View {
        HStack(spacing: SophosTheme.Spacing.lg) {
            HealthRingView(
                score: health.computedScore,
                status: health.overallStatus,
                size: 76
            )

            VStack(alignment: .leading, spacing: SophosTheme.Spacing.xs) {
                HStack(spacing: SophosTheme.Spacing.xs) {
                    Text(statusLabel(health.overallStatus))
                        .font(SophosTheme.Typography.title3(.semibold))
                        .foregroundColor(SophosTheme.Colors.healthColor(health.overallStatus))
                    if health.anyCheckSnoozed {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 12))
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                    }
                }

                Text("Score: \(health.computedScore) / 100")
                    .font(SophosTheme.Typography.subheadline())
                    .foregroundColor(SophosTheme.Colors.textSecondary)

                if let name = health.tenant?.name {
                    Text(name)
                        .font(SophosTheme.Typography.caption())
                        .foregroundColor(SophosTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }

    // MARK: - Checks grid

    private func checksGrid(_ health: AccountHealthResponse) -> some View {
        VStack(spacing: SophosTheme.Spacing.sm) {
            HealthCheckRow(
                icon: "lock.shield",
                label: "Protection",
                issues: health.protectionIssues,
                total: health.protectionTotal,
                goodLabel: "All endpoints protected",
                badLabel: "\(health.protectionIssues) endpoint\(health.protectionIssues == 1 ? "" : "s") not fully protected"
            )
            HealthCheckRow(
                icon: "gearshape.2",
                label: "Policy",
                issues: health.policyIssues,
                total: health.policyTotal,
                goodLabel: "Policies on recommended settings",
                badLabel: "\(health.policyIssues) polic\(health.policyIssues == 1 ? "y" : "ies") need review"
            )
            HealthCheckRow(
                icon: "minus.circle",
                label: "Exclusions",
                issues: health.exclusionRisks,
                total: nil,
                goodLabel: "No risky exclusions",
                badLabel: "\(health.exclusionRisks) risky exclusion\(health.exclusionRisks == 1 ? "" : "s") detected"
            )
            HealthCheckRow(
                icon: "hand.raised.slash",
                label: "Tamper Protection",
                issues: health.tamperIssues,
                total: health.tamperTotal,
                goodLabel: "Tamper protection enabled",
                badLabel: "\(health.tamperIssues) device\(health.tamperIssues == 1 ? "" : "s") unprotected"
            )

            // Firewall backup (optional — only shown when data is present)
            if let backup = health.networkDevice?.firewall?.firewallAutomaticBackup,
               let total = backup.total, total > 0 {
                let issues = backup.notOnRecommended ?? 0
                HealthCheckRow(
                    icon: "externaldrive.badge.checkmark",
                    label: "Firewall Backup",
                    issues: issues,
                    total: total,
                    goodLabel: "Automatic backup configured",
                    badLabel: "\(issues) firewall\(issues == 1 ? "" : "s") without backup"
                )
            }
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status.lowercased() {
        case "good": return "Healthy"
        case "fair": return "Fair"
        case "bad":  return "At Risk"
        default:     return status.capitalized
        }
    }
}

// MARK: - Check row

private struct HealthCheckRow: View {
    let icon: String
    let label: String
    let issues: Int
    let total: Int?
    let goodLabel: String
    let badLabel: String

    private var isGood: Bool { issues == 0 }
    private var iconColor: Color {
        isGood ? SophosTheme.Colors.statusHealthy : SophosTheme.Colors.statusCritical
    }

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {
            Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(iconColor)
                .font(.system(size: 16))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(SophosTheme.Typography.footnote(.semibold))
                    .foregroundColor(SophosTheme.Colors.textPrimary)

                Text(isGood ? goodLabel : badLabel)
                    .font(SophosTheme.Typography.caption())
                    .foregroundColor(
                        isGood ? SophosTheme.Colors.textSecondary
                               : SophosTheme.Colors.statusCritical
                    )
            }

            Spacer()

            if let total, total > 0 {
                Text("\(total - issues)/\(total)")
                    .font(SophosTheme.Typography.caption(.semibold))
                    .foregroundColor(isGood
                        ? SophosTheme.Colors.statusHealthy
                        : SophosTheme.Colors.textTertiary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Health Ring (unchanged)

struct HealthRingView: View {
    let score: Int
    let status: String
    let size: CGFloat

    var color: Color    { SophosTheme.Colors.healthColor(status) }
    var progress: CGFloat { CGFloat(score) / 100.0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 6)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
                .animation(.easeInOut(duration: 0.8), value: progress)
            Text("\(score)")
                .font(SophosTheme.Typography.headline(.semibold))
                .foregroundColor(SophosTheme.Colors.textPrimary)
        }
    }
}

// MARK: - Health Pill (kept for any other usage)

struct HealthPillView: View {
    let label: String
    let status: String

    var color: Color { SophosTheme.Colors.healthColor(status) }

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(SophosTheme.Typography.caption2())
                .foregroundColor(SophosTheme.Colors.textSecondary)
        }
    }
}
