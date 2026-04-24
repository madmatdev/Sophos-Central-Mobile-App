import SwiftUI

// MARK: - Alert status filter

private enum AlertStatusFilter: String, CaseIterable {
    case all        = ""
    case open       = "new"
    case closed     = "acknowledged"

    var label: String {
        switch self {
        case .all:    return "All"
        case .open:   return "Open"
        case .closed: return "Closed"
        }
    }

    var icon: String? {
        switch self {
        case .open:   return "circle.fill"
        case .closed: return "checkmark.circle.fill"
        case .all:    return nil
        }
    }

    var iconColor: Color {
        switch self {
        case .open:   return SophosTheme.Colors.statusCritical
        case .closed: return SophosTheme.Colors.statusHealthy
        case .all:    return .clear
        }
    }

}

// MARK: - View

struct AlertsListView: View {

    @State private var alerts: [SophosAlert] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedStatus: AlertStatusFilter = .all
    @State private var selectedSeverity: String? = nil
    @State private var searchText = ""
    @State private var selectedAlert: SophosAlert?

    // Acknowledge-all state
    @State private var showAcknowledgeAllConfirm = false
    @State private var isAcknowledgingAll = false
    @State private var acknowledgeAllResult: AcknowledgeAllResult?

    private let api = SophosAPIService.shared
    private let severities = ["All", "High", "Medium", "Low", "Info"]

    // Alerts that can be acknowledged
    private var acknowledgeable: [SophosAlert] {
        alerts.filter { $0.allowedActions?.contains("acknowledge") == true }
    }

    private var filtered: [SophosAlert] {
        var list = alerts

        // Status filter — client-side using allowedActions
        switch selectedStatus {
        case .open:
            list = list.filter { $0.allowedActions?.contains("acknowledge") == true }
        case .closed:
            list = list.filter { $0.allowedActions?.contains("acknowledge") != true }
        case .all:
            break
        }

        if let sev = selectedSeverity {
            list = list.filter { $0.severity.lowercased() == sev.lowercased() }
        }
        if !searchText.isEmpty {
            list = list.filter {
                ($0.description ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.category ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.product ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {

                // Acknowledge-all result banner
                if let result = acknowledgeAllResult {
                    AcknowledgeAllBanner(result: result) {
                        acknowledgeAllResult = nil
                    }
                }

                // Filter bar — Status | Severity
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SophosTheme.Spacing.xs) {

                        // Status pills (client-side filter on allowedActions)
                        ForEach(AlertStatusFilter.allCases, id: \.self) { status in
                            FilterPill(
                                label: status.label,
                                isSelected: selectedStatus == status,
                                icon: status.icon,
                                iconColor: status.iconColor
                            ) {
                                selectedStatus = status
                            }
                        }

                        Divider().frame(height: 18).foregroundColor(SophosTheme.Colors.divider)

                        // Severity pills
                        ForEach(severities, id: \.self) { sev in
                            FilterPill(
                                label: sev,
                                isSelected: (sev == "All" && selectedSeverity == nil) ||
                                            sev.lowercased() == selectedSeverity
                            ) {
                                selectedSeverity = sev == "All" ? nil : sev.lowercased()
                            }
                        }
                    }
                    .padding(.horizontal, SophosTheme.Spacing.md)
                    .padding(.vertical, SophosTheme.Spacing.sm)
                }
                .background(SophosTheme.Colors.navigationBar)

                // Results summary
                if !alerts.isEmpty && !isLoading {
                    HStack {
                        Text("\(filtered.count) alert\(filtered.count == 1 ? "" : "s")")
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                        Spacer()
                        Text(selectedStatus.label)
                            .font(SophosTheme.Typography.caption2(.semibold))
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                    }
                    .padding(.horizontal, SophosTheme.Spacing.md)
                    .padding(.vertical, 4)
                    .background(SophosTheme.Colors.backgroundPrimary)
                }

                if isLoading {
                    Spacer()
                    ProgressView().tint(SophosTheme.Colors.sophosBlue)
                    Spacer()
                } else if let error = errorMessage {
                    ErrorView(message: error) {
                        Task { await load() }
                    }
                } else if filtered.isEmpty {
                    Spacer()
                    VStack(spacing: SophosTheme.Spacing.sm) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 48))
                            .foregroundColor(SophosTheme.Colors.statusHealthy)
                        Text("No alerts found")
                            .font(SophosTheme.Typography.headline())
                            .foregroundColor(SophosTheme.Colors.textPrimary)
                        Text("Your environment is clean for the selected filter.")
                            .font(SophosTheme.Typography.subheadline())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(filtered) { alert in
                            Button { selectedAlert = alert } label: {
                                AlertListRow(alert: alert)
                            }
                            .listRowBackground(SophosTheme.Colors.backgroundCard)
                            .listRowSeparatorTint(SophosTheme.Colors.divider)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(SophosTheme.Colors.backgroundPrimary)
                    .refreshable { await load() }
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search alerts..."
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isAcknowledgingAll {
                    ProgressView().tint(SophosTheme.Colors.sophosBlue)
                } else if !acknowledgeable.isEmpty {
                    Button {
                        showAcknowledgeAllConfirm = true
                    } label: {
                        Label("Acknowledge All", systemImage: "checkmark.circle")
                            .font(SophosTheme.Typography.subheadline(.semibold))
                    }
                    .foregroundColor(SophosTheme.Colors.sophosBlue)
                }
            }
        }
        .confirmationDialog(
            "Acknowledge \(acknowledgeable.count) alert\(acknowledgeable.count == 1 ? "" : "s")?",
            isPresented: $showAcknowledgeAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Acknowledge All") {
                Task { await acknowledgeAll() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will acknowledge all \(acknowledgeable.count) alert\(acknowledgeable.count == 1 ? "" : "s") that allow acknowledgment. This action cannot be undone.")
        }
        .sheet(item: $selectedAlert) { alert in
            AlertDetailView(alert: alert)
        }
        .task { await load() }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.fetchAlerts()
            alerts = response.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func acknowledgeAll() async {
        let ids = acknowledgeable.map { $0.id }
        guard !ids.isEmpty else { return }

        isAcknowledgingAll = true
        acknowledgeAllResult = nil
        defer { isAcknowledgingAll = false }

        let succeeded = await api.acknowledgeAlerts(alertIds: ids)

        // Remove successfully acknowledged alerts from local list
        alerts.removeAll { succeeded.contains($0.id) }

        acknowledgeAllResult = AcknowledgeAllResult(
            succeeded: succeeded.count,
            failed: ids.count - succeeded.count
        )
    }
}

// MARK: - Acknowledge-all result model

struct AcknowledgeAllResult {
    let succeeded: Int
    let failed: Int
    var isFullSuccess: Bool { failed == 0 }
}

// MARK: - Acknowledge-all banner

private struct AcknowledgeAllBanner: View {
    let result: AcknowledgeAllResult
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {
            Image(systemName: result.isFullSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(result.isFullSuccess ? SophosTheme.Colors.statusHealthy : SophosTheme.Colors.statusWarning)

            VStack(alignment: .leading, spacing: 2) {
                if result.isFullSuccess {
                    Text("\(result.succeeded) alert\(result.succeeded == 1 ? "" : "s") acknowledged")
                        .font(SophosTheme.Typography.subheadline(.semibold))
                        .foregroundColor(SophosTheme.Colors.statusHealthy)
                } else {
                    Text("\(result.succeeded) acknowledged, \(result.failed) failed")
                        .font(SophosTheme.Typography.subheadline(.semibold))
                        .foregroundColor(SophosTheme.Colors.statusWarning)
                }
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SophosTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, SophosTheme.Spacing.md)
        .padding(.vertical, SophosTheme.Spacing.sm)
        .background(
            (result.isFullSuccess ? SophosTheme.Colors.statusHealthy : SophosTheme.Colors.statusWarning)
                .opacity(0.12)
        )
    }
}

// MARK: - Alert list row

struct AlertListRow: View {
    let alert: SophosAlert

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(SophosTheme.Colors.severityColor(alert.severity))
                .frame(width: 4)
                .frame(minHeight: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.description ?? alert.type ?? "Security Alert")
                    .font(SophosTheme.Typography.subheadline(.semibold))
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: SophosTheme.Spacing.xs) {
                    SeverityBadge(severity: alert.severity)

                    if let category = alert.category {
                        Text(category)
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                    }
                    if let product = alert.product {
                        Text("·")
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                        Text(product)
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                    }
                }

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

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(SophosTheme.Colors.textTertiary)
        }
        .padding(.vertical, SophosTheme.Spacing.xs)
    }
}

// MARK: - Filter pill

struct FilterPill: View {
    let label: String
    let isSelected: Bool
    var icon: String? = nil
    var iconColor: Color = .clear
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 7))
                        .foregroundColor(isSelected ? .white : iconColor)
                }
                Text(label)
                    .font(SophosTheme.Typography.footnote(isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : SophosTheme.Colors.textSecondary)
            }
            .padding(.horizontal, SophosTheme.Spacing.sm)
            .padding(.vertical, SophosTheme.Spacing.xxs)
            .background(isSelected ? SophosTheme.Colors.sophosBlue : SophosTheme.Colors.backgroundCard2)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Error view

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: SophosTheme.Spacing.md) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(SophosTheme.Colors.statusWarning)
            Text("Something went wrong")
                .font(SophosTheme.Typography.headline())
                .foregroundColor(SophosTheme.Colors.textPrimary)
            Text(message)
                .font(SophosTheme.Typography.subheadline())
                .foregroundColor(SophosTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try Again", action: retry)
                .font(SophosTheme.Typography.headline())
                .foregroundColor(.white)
                .padding(.horizontal, SophosTheme.Spacing.xl)
                .padding(.vertical, SophosTheme.Spacing.sm)
                .background(SophosTheme.Colors.sophosBlue)
                .clipShape(Capsule())
            Spacer()
        }
        .padding()
    }
}
