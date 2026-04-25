import SwiftUI

struct AlertDetailView: View {

    let alert: SophosAlert
    @Environment(\.dismiss) private var dismiss

    @State private var actionInProgress: String?       // action key currently running
    @State private var completedActions: Set<String> = []
    @State private var actionErrors: [String: String] = [:]

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
                            actionInProgress: actionInProgress,
                            completedActions: completedActions,
                            actionErrors: actionErrors
                        ) { action in
                            Task { await perform(action: action) }
                        }

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

    private func perform(action: String) async {
        actionInProgress = action
        actionErrors.removeValue(forKey: action)
        defer { actionInProgress = nil }
        do {
            switch action {
            case "acknowledge": try await api.acknowledgeAlert(alertId: alert.id)
            case "clearThreat": try await api.clearThreat(alertId: alert.id)
            case "cleanVirus":  try await api.cleanVirus(alertId: alert.id)
            case "cleanPua":    try await api.cleanPua(alertId: alert.id)
            default: break
            }
            completedActions.insert(action)
        } catch {
            actionErrors[action] = error.localizedDescription
        }
    }
}

// MARK: - Detail row

struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = SophosTheme.Colors.textPrimary

    var body: some View {
        HStack {
            Text(label)
                .font(SophosTheme.Typography.subheadline())
                .foregroundColor(SophosTheme.Colors.textSecondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(SophosTheme.Typography.subheadline(.semibold))
                .foregroundColor(valueColor)
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
    let actionInProgress: String?
    let completedActions: Set<String>
    let actionErrors: [String: String]
    let onAction: (String) -> Void

    private let supportedActions = ["acknowledge", "clearThreat", "cleanVirus", "cleanPua"]

    private var availableActions: [String] {
        guard let allowed = alert.allowedActions else { return [] }
        return supportedActions.filter { allowed.contains($0) }
    }

    var body: some View {
        if !availableActions.isEmpty {
            VStack(alignment: .leading, spacing: SophosTheme.Spacing.sm) {
                Text("Actions")
                    .sophosSectionHeader()
                    .padding(.horizontal, SophosTheme.Spacing.md)
                    .padding(.top, SophosTheme.Spacing.sm)

                ForEach(availableActions, id: \.self) { action in
                    let meta = ActionMeta(action)
                    let isRunning   = actionInProgress == action
                    let isDone      = completedActions.contains(action)
                    let errorMsg    = actionErrors[action]
                    let isBlocked   = actionInProgress != nil && !isRunning

                    VStack(spacing: SophosTheme.Spacing.xs) {
                        if isDone {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(SophosTheme.Colors.statusHealthy)
                                Text("\(meta.label) completed")
                                    .font(SophosTheme.Typography.subheadline())
                                    .foregroundColor(SophosTheme.Colors.statusHealthy)
                            }
                            .padding(SophosTheme.Spacing.sm)
                            .frame(maxWidth: .infinity)
                            .background(SophosTheme.Colors.statusHealthy.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
                        } else {
                            Button { onAction(action) } label: {
                                HStack(spacing: SophosTheme.Spacing.sm) {
                                    if isRunning {
                                        ProgressView().tint(.white).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: meta.icon)
                                    }
                                    Text(isRunning ? "\(meta.label)…" : meta.label)
                                }
                                .font(SophosTheme.Typography.headline())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(isBlocked ? meta.color.opacity(0.4) : meta.color)
                                .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
                            }
                            .disabled(isRunning || isBlocked)
                        }

                        if let err = errorMsg {
                            Text(err)
                                .font(SophosTheme.Typography.caption())
                                .foregroundColor(SophosTheme.Colors.statusCritical)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, SophosTheme.Spacing.md)
                }

                Spacer().frame(height: SophosTheme.Spacing.xs)
            }
            .sophosCard()
        }
    }
}

// MARK: - Action metadata

private struct ActionMeta {
    let label: String
    let icon: String
    let color: Color

    init(_ action: String) {
        switch action {
        case "acknowledge":
            label = "Acknowledge Alert"
            icon  = "checkmark.circle"
            color = SophosTheme.Colors.sophosBlue
        case "clearThreat":
            label = "Clear Threat"
            icon  = "shield.slash"
            color = SophosTheme.Colors.statusWarning
        case "cleanVirus":
            label = "Clean Virus"
            icon  = "cross.circle"
            color = SophosTheme.Colors.statusCritical
        case "cleanPua":
            label = "Clean PUA"
            icon  = "trash.circle"
            color = SophosTheme.Colors.statusCritical
        default:
            label = action.capitalized
            icon  = "bolt.circle"
            color = SophosTheme.Colors.sophosBlue
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
