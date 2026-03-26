import SwiftUI

struct CaseDetailView: View {

    let sophosCase: SophosCase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SophosTheme.Spacing.md) {

                        // Header
                        VStack(alignment: .leading, spacing: SophosTheme.Spacing.sm) {
                            HStack(spacing: SophosTheme.Spacing.xs) {
                                SeverityBadge(severity: sophosCase.severity)
                                CaseStatusBadge(status: sophosCase.status)
                                if sophosCase.managedBy?.lowercased() == "sophos" {
                                    Text("MDR Managed")
                                        .font(SophosTheme.Typography.caption2(.semibold))
                                        .foregroundColor(SophosTheme.Colors.sophosBlue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(SophosTheme.Colors.sophosBlue.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                Spacer()
                            }

                            Text(sophosCase.name ?? "Unnamed Case")
                                .font(SophosTheme.Typography.title3(.semibold))
                                .foregroundColor(SophosTheme.Colors.textPrimary)

                            if let overview = sophosCase.overview {
                                Text(overview)
                                    .font(SophosTheme.Typography.body())
                                    .foregroundColor(SophosTheme.Colors.textSecondary)
                            }
                        }
                        .padding(SophosTheme.Spacing.md)
                        .sophosCard()

                        // Detection count
                        if let count = sophosCase.detectionCount, count > 0 {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                    .foregroundColor(SophosTheme.Colors.sophosBlue)
                                Text("\(count) Detections Associated")
                                    .font(SophosTheme.Typography.subheadline(.semibold))
                                    .foregroundColor(SophosTheme.Colors.textPrimary)
                                Spacer()
                            }
                            .padding(SophosTheme.Spacing.md)
                            .sophosCard()
                        }

                        // Details
                        VStack(spacing: 0) {
                            Text("Case Details")
                                .sophosSectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, SophosTheme.Spacing.md)
                                .padding(.bottom, SophosTheme.Spacing.xs)

                            if let type = sophosCase.type {
                                DetailRow(label: "Type", value: type.capitalized)
                                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                            }
                            if let assignee = sophosCase.assignee?.name {
                                DetailRow(label: "Assignee", value: assignee)
                                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                            }
                            if let managed = sophosCase.managedBy {
                                DetailRow(label: "Managed By", value: managed.lowercased() == "sophos" ? "Sophos MDR" : "Self-managed")
                                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                            }
                            if let created = sophosCase.createdDate {
                                DetailRow(label: "Created", value: created.formatted(date: .abbreviated, time: .shortened))
                                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                            }
                            if let updated = sophosCase.updatedDate {
                                DetailRow(label: "Last Updated", value: updated.formatted(date: .abbreviated, time: .shortened))
                            }
                        }
                        .sophosCard()

                        // Case ID
                        VStack(alignment: .leading, spacing: SophosTheme.Spacing.xs) {
                            Text("Case ID")
                                .sophosSectionHeader()
                            Text(sophosCase.id)
                                .font(.custom("Menlo", size: 12))
                                .foregroundColor(SophosTheme.Colors.textSecondary)
                                .textSelection(.enabled)
                        }
                        .padding(SophosTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sophosCard()

                        Spacer().frame(height: SophosTheme.Spacing.xl)
                    }
                    .padding(SophosTheme.Spacing.md)
                }
            }
            .navigationTitle("Case Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(SophosTheme.Colors.sophosBlue)
                }
            }
        }
    }
}
