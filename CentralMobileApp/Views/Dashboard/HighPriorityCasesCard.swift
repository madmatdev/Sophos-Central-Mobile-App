import SwiftUI

struct HighPriorityCasesCard: View {

    let cases: [SophosCase]
    let isLoading: Bool
    var onViewAll: (() -> Void)?

    private var openCases:   [SophosCase] { cases.filter { $0.status.lowercased() != "closed" } }
    private var highCases:   [SophosCase] { cases.filter { $0.severity.lowercased() == "high" } }
    private var previewCases: [SophosCase] { Array(openCases.prefix(3)) }

    var body: some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.md) {

            // Header
            HStack {
                Label("High Priority Cases", systemImage: "exclamationmark.shield.fill")
                    .font(SophosTheme.Typography.headline())
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                Spacer()
                if isLoading {
                    ProgressView().tint(SophosTheme.Colors.sophosBlue).scaleEffect(0.8)
                } else if !cases.isEmpty {
                    Button("View All") { onViewAll?() }
                        .font(SophosTheme.Typography.footnote(.semibold))
                        .foregroundColor(SophosTheme.Colors.sophosBlue)
                }
            }

            if isLoading {
                SkeletonRow()
                SkeletonRow()
            } else if cases.isEmpty {
                EmptyStateRow(icon: "checkmark.shield.fill", message: "No high priority cases")
            } else {

                // Summary
                HStack(spacing: SophosTheme.Spacing.md) {
                    CaseStatCell(value: openCases.count,  label: "Open",     color: SophosTheme.Colors.statusCritical)
                    CaseStatCell(value: highCases.count,  label: "High",     color: SophosTheme.Colors.severityHigh)
                    CaseStatCell(
                        value: cases.filter { $0.managedBy?.lowercased() == "sophos" }.count,
                        label: "MDR",
                        color: SophosTheme.Colors.sophosBlue
                    )
                    Spacer()
                }

                Divider().background(SophosTheme.Colors.divider)

                // Case rows
                ForEach(previewCases) { c in
                    CaseRowMini(sophosCase: c)
                    if c.id != previewCases.last?.id {
                        Divider().background(SophosTheme.Colors.divider).padding(.leading, 32)
                    }
                }

                if openCases.count > 3 {
                    Button {
                        onViewAll?()
                    } label: {
                        Text("+\(openCases.count - 3) more cases")
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

// MARK: - Case stat cell

struct CaseStatCell: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(SophosTheme.Typography.title3(.semibold))
                .foregroundColor(value > 0 ? color : SophosTheme.Colors.textTertiary)
            Text(label)
                .font(SophosTheme.Typography.caption2())
                .foregroundColor(SophosTheme.Colors.textSecondary)
        }
        .frame(minWidth: 60)
    }
}

// MARK: - Case row mini

struct CaseRowMini: View {
    let sophosCase: SophosCase

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.shield")
                .foregroundColor(SophosTheme.Colors.severityColor(sophosCase.severity))
                .font(.system(size: 18))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(sophosCase.name ?? "Unnamed Case")
                    .font(SophosTheme.Typography.footnote(.semibold))
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: SophosTheme.Spacing.xs) {
                    SeverityBadge(severity: sophosCase.severity)

                    Text(sophosCase.statusDisplay)
                        .font(SophosTheme.Typography.caption2())
                        .foregroundColor(SophosTheme.Colors.textSecondary)

                    if sophosCase.managedBy?.lowercased() == "sophos" {
                        Text("MDR")
                            .font(SophosTheme.Typography.caption2(.semibold))
                            .foregroundColor(SophosTheme.Colors.sophosBlue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(SophosTheme.Colors.sophosBlue.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if let detections = sophosCase.detectionCount, detections > 0 {
                        Label("\(detections)", systemImage: "waveform.path.ecg")
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                    }
                }
            }
        }
    }
}
