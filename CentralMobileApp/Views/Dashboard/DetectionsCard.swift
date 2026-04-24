import SwiftUI

struct DetectionsCard: View {

    let counts: DetectionCountsResponse?
    let isLoading: Bool
    var onViewAll: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.md) {

            // Header
            HStack {
                Label("Detections", systemImage: "shield.lefthalf.filled.trianglebadge.exclamationmark")
                    .font(SophosTheme.Typography.headline())
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                Spacer()
                if isLoading {
                    ProgressView().tint(SophosTheme.Colors.sophosBlue).scaleEffect(0.8)
                } else if counts != nil {
                    Button("View All") { onViewAll?() }
                        .font(SophosTheme.Typography.footnote(.semibold))
                        .foregroundColor(SophosTheme.Colors.sophosBlue)
                }
            }

            if isLoading {
                SkeletonRow()
                SkeletonRow()
            } else if let counts {
                if counts.totalCount == 0 {
                    EmptyStateRow(icon: "checkmark.shield.fill", message: "No detections in this period")
                } else {
                    // Total count headline
                    HStack(alignment: .firstTextBaseline, spacing: SophosTheme.Spacing.xs) {
                        Text("\(counts.totalCount)")
                            .font(SophosTheme.Typography.title3(.semibold))
                            .foregroundColor(SophosTheme.Colors.textPrimary)
                        Text("total detections")
                            .font(SophosTheme.Typography.footnote())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                        Spacer()
                    }

                    // Severity breakdown bar
                    DetectionSeverityBar(counts: counts)

                    // Severity count pills
                    HStack(spacing: SophosTheme.Spacing.xs) {
                        if counts.critical > 0 {
                            DetectionSeverityPill(label: "Critical", count: counts.critical, color: SophosTheme.Colors.statusCritical)
                        }
                        if counts.high > 0 {
                            DetectionSeverityPill(label: "High", count: counts.high, color: SophosTheme.Colors.statusWarning)
                        }
                        if counts.medium > 0 {
                            DetectionSeverityPill(label: "Medium", count: counts.medium, color: .orange)
                        }
                        if counts.low > 0 {
                            DetectionSeverityPill(label: "Low", count: counts.low, color: SophosTheme.Colors.textSecondary)
                        }
                        if counts.info > 0 {
                            DetectionSeverityPill(label: "Info", count: counts.info, color: SophosTheme.Colors.sophosBlue)
                        }
                    }
                }
            } else {
                EmptyStateRow(icon: "exclamationmark.triangle", message: "Detection data unavailable")
            }
        }
        .padding(SophosTheme.Spacing.md)
        .sophosCard()
    }
}

// MARK: - Severity bar

private struct DetectionSeverityBar: View {
    let counts: DetectionCountsResponse

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                if counts.critical > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SophosTheme.Colors.statusCritical)
                        .frame(width: barWidth(geo.size.width, count: counts.critical))
                }
                if counts.high > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SophosTheme.Colors.statusWarning)
                        .frame(width: barWidth(geo.size.width, count: counts.high))
                }
                if counts.medium > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.orange)
                        .frame(width: barWidth(geo.size.width, count: counts.medium))
                }
                if counts.low > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SophosTheme.Colors.textSecondary)
                        .frame(width: barWidth(geo.size.width, count: counts.low))
                }
                if counts.info > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SophosTheme.Colors.sophosBlue)
                        .frame(width: barWidth(geo.size.width, count: counts.info))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
        }
        .frame(height: 6)
    }

    private func barWidth(_ total: CGFloat, count: Int) -> CGFloat {
        guard counts.totalCount > 0 else { return 0 }
        return (total - 8) * CGFloat(count) / CGFloat(counts.totalCount)
    }
}

// MARK: - Severity pill

private struct DetectionSeverityPill: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .font(SophosTheme.Typography.caption2(.semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}
