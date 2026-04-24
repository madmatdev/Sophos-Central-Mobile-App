import SwiftUI

struct CaseDetailView: View {

    let sophosCase: SophosCase
    var onResolved: ((SophosCase) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var currentCase: SophosCase
    @State private var showResolveConfirm = false
    @State private var isResolving = false
    @State private var resolveError: String?

    private let api = SophosAPIService.shared

    init(sophosCase: SophosCase, onResolved: ((SophosCase) -> Void)? = nil) {
        self.sophosCase = sophosCase
        self.onResolved = onResolved
        _currentCase = State(initialValue: sophosCase)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SophosTheme.Spacing.md) {

                        // Header card
                        VStack(alignment: .leading, spacing: SophosTheme.Spacing.sm) {
                            HStack(spacing: SophosTheme.Spacing.xs) {
                                SeverityBadge(severity: currentCase.severity)
                                CaseStatusBadge(status: currentCase.status)
                                if currentCase.managedBy?.lowercased() == "sophos" {
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

                            Text(currentCase.name ?? "Unnamed Case")
                                .font(SophosTheme.Typography.title3(.semibold))
                                .foregroundColor(SophosTheme.Colors.textPrimary)

                            if let overview = currentCase.overview {
                                Text(overview)
                                    .font(SophosTheme.Typography.body())
                                    .foregroundColor(SophosTheme.Colors.textSecondary)
                            }
                        }
                        .padding(SophosTheme.Spacing.md)
                        .sophosCard()

                        // Detection count
                        if let count = currentCase.detectionCount, count > 0 {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                    .foregroundColor(SophosTheme.Colors.sophosBlue)
                                Text("\(count) Detection\(count == 1 ? "" : "s") Associated")
                                    .font(SophosTheme.Typography.subheadline(.semibold))
                                    .foregroundColor(SophosTheme.Colors.textPrimary)
                                Spacer()
                            }
                            .padding(SophosTheme.Spacing.md)
                            .sophosCard()
                        }

                        // Case details card
                        VStack(spacing: 0) {
                            Text("Case Details")
                                .sophosSectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, SophosTheme.Spacing.md)
                                .padding(.bottom, SophosTheme.Spacing.xs)

                            if let type = currentCase.type {
                                DetailRow(label: "Type", value: typeDisplay(type))
                                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                            }
                            DetailRow(label: "Status", value: currentCase.statusDisplay,
                                      valueColor: statusColor(currentCase.status))
                            Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                            DetailRow(label: "Severity", value: severityDisplay(currentCase.severity),
                                      valueColor: SophosTheme.Colors.severityColor(currentCase.severity))
                            Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                            if let assignee = currentCase.assignee?.name {
                                DetailRow(label: "Assignee", value: assignee)
                                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                            }
                            if let managed = currentCase.managedBy {
                                DetailRow(label: "Managed By",
                                          value: managed.lowercased() == "sophos" ? "Sophos MDR" : "Self-Managed")
                                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                            }
                            if let created = currentCase.createdDate {
                                DetailRow(label: "Created", value: created.formatted(date: .abbreviated, time: .shortened))
                                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                            }
                            if let updated = currentCase.updatedDate {
                                DetailRow(label: "Last Updated", value: updated.formatted(date: .abbreviated, time: .shortened))
                            }
                        }
                        .sophosCard()

                        // Resolve Case action (self-managed only, not already resolved)
                        if currentCase.isSelfManaged && !currentCase.isResolved {
                            VStack(spacing: SophosTheme.Spacing.sm) {
                                Text("Actions")
                                    .sophosSectionHeader()
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // Error feedback
                                if let err = resolveError {
                                    HStack(spacing: SophosTheme.Spacing.xs) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(SophosTheme.Colors.statusCritical)
                                        Text(err)
                                            .font(SophosTheme.Typography.caption())
                                            .foregroundColor(SophosTheme.Colors.statusCritical)
                                    }
                                    .padding(SophosTheme.Spacing.xs)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(SophosTheme.Colors.statusCritical.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
                                }

                                Button {
                                    showResolveConfirm = true
                                } label: {
                                    HStack {
                                        if isResolving {
                                            ProgressView().tint(.white).scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "checkmark.circle")
                                        }
                                        Text(isResolving ? "Resolving…" : "Resolve Case")
                                            .font(SophosTheme.Typography.subheadline(.semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, SophosTheme.Spacing.sm)
                                    .background(SophosTheme.Colors.statusHealthy)
                                    .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.md))
                                }
                                .disabled(isResolving)
                            }
                            .padding(SophosTheme.Spacing.md)
                            .sophosCard()
                        }

                        // Case ID
                        VStack(alignment: .leading, spacing: SophosTheme.Spacing.xs) {
                            Text("Case ID")
                                .sophosSectionHeader()
                            Text(currentCase.id)
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
            .confirmationDialog(
                "Resolve \"\(currentCase.name ?? "this case")\"?",
                isPresented: $showResolveConfirm,
                titleVisibility: .visible
            ) {
                Button("Resolve Case") {
                    Task { await resolveCase() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will mark the case as Resolved. Only self-managed cases can be closed via the API.")
            }
        }
    }

    // MARK: - Actions

    private func resolveCase() async {
        isResolving = true
        resolveError = nil
        defer { isResolving = false }
        do {
            let updated = try await api.updateCase(
                id: currentCase.id,
                request: UpdateCaseRequest(status: "resolved")
            )
            currentCase = updated
            onResolved?(updated)
        } catch {
            resolveError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func typeDisplay(_ type: String) -> String {
        switch type {
        case "activeThreat":        return "Active Threat"
        case "investigation":       return "Investigation"
        case "incident":            return "Incident"
        case "healthCheck":         return "Health Check"
        case "postureImprovement":  return "Posture Improvement"
        case "customerRequest":     return "Customer Request"
        case "managedRisk":         return "Managed Risk"
        case "generalRequest":      return "General Request"
        case "exposure":            return "Exposure"
        case "duplicate":           return "Duplicate"
        case "hunt":                return "Hunt"
        default:                    return type.capitalized
        }
    }

    private func severityDisplay(_ severity: String) -> String {
        switch severity {
        case "notSet":        return "Not Set"
        case "informational": return "Informational"
        default:              return severity.capitalized
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "new":            return SophosTheme.Colors.statusCritical
        case "investigating":  return SophosTheme.Colors.statusWarning
        case "onHold":         return SophosTheme.Colors.textSecondary
        case "actionRequired": return SophosTheme.Colors.statusCritical
        case "resolved":       return SophosTheme.Colors.statusHealthy
        default:               return SophosTheme.Colors.textSecondary
        }
    }
}
