import SwiftUI

struct AlertDetailView: View {

    let alert: SophosAlert
    @Environment(\.dismiss) private var dismiss
    @State private var isAcknowledging = false
    @State private var acknowledgeSuccess = false
    @State private var acknowledgeError: String?

    private let api = SophosAPIService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SophosTheme.Spacing.md) {

                        // Severity banner
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(SophosTheme.Colors.severityColor(alert.severity))
                                .frame(width: 4)
                            VStack(alignment: .leading, spacing: 4) {
                                SeverityBadge(severity: alert.severity)
                                Text(alert.description ?? alert.type ?? "Security Alert")
                                    .font(SophosTheme.Typography.title3(.semibold))
                                    .foregroundColor(SophosTheme.Colors.textPrimary)
                            }
                            Spacer()
                        }
                        .padding(SophosTheme.Spacing.md)
                        .sophosCard()

                        AlertDetailsCard(alert: alert)
                        AlertIdCard(alertId: alert.id)
                        AlertActionsCard(
                            alert: alert,
                            isAcknowledging: isAcknowledging,
                            acknowledgeSuccess: acknowledgeSuccess,
                            acknowledgeError: acknowledgeError,
                            onAcknowledge: { Task { await acknowledge() } }
                        )

                        Spacer().frame(height: SophosTheme.Spacing.xl)
                    }
                    .padding(SophosTheme.Spacing.md)
                }
            }
            .navigationTitle("Alert Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(SophosTheme.Colors.sophosBlue)
                }
            }
        }
    }

    private func acknowledge() async {
        isAcknowledging = true
        acknowledgeError = nil
        defer { isAcknowledging = false }
        do {
            try await api.acknowledgeAlert(alertId: alert.id)
            acknowledgeSuccess = true
        } catch {
            acknowledgeError = error.localizedDescription
        }
    }
}

// MARK: - Detail row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(SophosTheme.Typography.subheadline())
                .foregroundColor(SophosTheme.Colors.textSecondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(SophosTheme.Typography.subheadline(.semibold))
                .foregroundColor(SophosTheme.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
            Spacer()
        }
        .padding(.horizontal, SophosTheme.Spacing.md)
        .padding(.vertical, SophosTheme.Spacing.sm)
    }
}

private struct AlertIdCard: View {
    let alertId: String
    var body: some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.xs) {
            Text("Alert ID").sophosSectionHeader()
            Text(alertId)
                .font(SophosTheme.Typography.caption())
                .foregroundColor(SophosTheme.Colors.textSecondary)
                .textSelection(.enabled)
        }
        .padding(SophosTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sophosCard()
    }
}

private struct AlertActionsCard: View {
    let alert: SophosAlert
    let isAcknowledging: Bool
    let acknowledgeSuccess: Bool
    let acknowledgeError: String?
    let onAcknowledge: () -> Void
    var body: some View {
        if let actions = alert.allowedActions, actions.contains("acknowledge") {
            VStack(spacing: SophosTheme.Spacing.sm) {
                if acknowledgeSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(SophosTheme.Colors.statusHealthy)
                        Text("Alert acknowledged")
                            .font(SophosTheme.Typography.subheadline())
                            .foregroundColor(SophosTheme.Colors.statusHealthy)
                    }
                    .padding(SophosTheme.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(SophosTheme.Colors.statusHealthy.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
                } else {
                    Button(action: onAcknowledge) {
                        HStack {
                            if isAcknowledging {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle")
                            }
                            Text(isAcknowledging ? "Acknowledging..." : "Acknowledge Alert")
                        }
                        .font(SophosTheme.Typography.headline())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(SophosTheme.Colors.sophosBlue)
                        .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
                    }
                    .disabled(isAcknowledging)
                }
                if let error = acknowledgeError {
                    Text(error)
                        .font(SophosTheme.Typography.caption())
                        .foregroundColor(SophosTheme.Colors.statusCritical)
                }
            }
        }
    }
}

private struct AlertDetailsCard: View {
    let alert: SophosAlert
    var body: some View {
        VStack(spacing: 0) {
            if let category = alert.category {
                DetailRow(label: "Category", value: category)
                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
            }
            if let product = alert.product {
                DetailRow(label: "Product", value: product)
                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
            }
            if let date = alert.raisedDate {
                DetailRow(label: "Raised", value: date.formatted(date: .abbreviated, time: .shortened))
                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
            }
            if let person = alert.person?.name {
                DetailRow(label: "User", value: person)
                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
            }
            if let agentType = alert.managedAgent?.type {
                DetailRow(label: "Device Type", value: agentType.capitalized)
            }
        }
        .sophosCard()
    }
}
