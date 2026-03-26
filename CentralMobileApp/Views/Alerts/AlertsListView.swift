import SwiftUI

struct AlertsListView: View {

    @State private var alerts: [SophosAlert] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedSeverity: String? = nil
    @State private var searchText = ""
    @State private var selectedAlert: SophosAlert?

    private let api = SophosAPIService.shared

    private let severities = ["All", "High", "Medium", "Low", "Info"]

    private var filtered: [SophosAlert] {
        var list = alerts
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

                // Severity filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SophosTheme.Spacing.xs) {
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
        .sheet(item: $selectedAlert) { alert in
            AlertDetailView(alert: alert)
        }
        .task { await load() }
    }

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
                    Text(date, style: .relative)
                        .font(SophosTheme.Typography.caption2())
                        .foregroundColor(SophosTheme.Colors.textTertiary)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(SophosTheme.Typography.footnote(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : SophosTheme.Colors.textSecondary)
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
