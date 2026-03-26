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
                // Overall score ring
                HStack(spacing: SophosTheme.Spacing.lg) {
                    HealthRingView(
                        score: health.overall.score ?? 0,
                        status: health.overall.status,
                        size: 80
                    )

                    VStack(alignment: .leading, spacing: SophosTheme.Spacing.xs) {
                        Text(statusLabel(health.overall.status))
                            .font(SophosTheme.Typography.title3(.semibold))
                            .foregroundColor(SophosTheme.Colors.healthColor(health.overall.status))

                        if let score = health.overall.score {
                            Text("Score: \(score)/100")
                                .font(SophosTheme.Typography.subheadline())
                                .foregroundColor(SophosTheme.Colors.textSecondary)
                        }
                    }
                    Spacer()
                }

                Divider().background(SophosTheme.Colors.divider)

                // Per-product breakdown
                HStack(spacing: SophosTheme.Spacing.md) {
                    if let ep = health.endpoint {
                        HealthPillView(label: "Endpoint", status: ep.status)
                    }
                    if let srv = health.server {
                        HealthPillView(label: "Server", status: srv.status)
                    }
                    if let fw = health.firewall {
                        HealthPillView(label: "Firewall", status: fw.status)
                    }
                    if let em = health.email {
                        HealthPillView(label: "Email", status: em.status)
                    }
                }
            } else if !isLoading {
                EmptyStateRow(icon: "shield.slash", message: "Health data unavailable")
            } else {
                SkeletonRow()
                SkeletonRow()
            }
        }
        .padding(SophosTheme.Spacing.md)
        .sophosCard()
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

// MARK: - Health Ring

struct HealthRingView: View {
    let score: Int
    let status: String
    let size: CGFloat

    var color: Color { SophosTheme.Colors.healthColor(status) }
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

// MARK: - Health Pill

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
