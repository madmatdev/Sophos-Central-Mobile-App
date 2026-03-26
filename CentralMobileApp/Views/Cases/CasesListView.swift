import SwiftUI

struct CasesListView: View {

    @State private var cases: [SophosCase] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedStatus: String? = nil
    @State private var selectedSeverity: String? = nil
    @State private var searchText = ""
    @State private var selectedCase: SophosCase?

    private let api = SophosAPIService.shared

    private var filtered: [SophosCase] {
        var list = cases
        if let status = selectedStatus {
            list = list.filter { $0.status.lowercased() == status }
        }
        if let severity = selectedSeverity {
            list = list.filter { $0.severity.lowercased() == severity }
        }
        if !searchText.isEmpty {
            list = list.filter {
                ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.overview ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {

                // Filter bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SophosTheme.Spacing.xs) {
                        Text("Status:")
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                        FilterPill(label: "All",         isSelected: selectedStatus == nil)        { selectedStatus = nil }
                        FilterPill(label: "Open",        isSelected: selectedStatus == "open")     { selectedStatus = "open" }
                        FilterPill(label: "In Progress", isSelected: selectedStatus == "inprogress") { selectedStatus = "inprogress" }

                        Divider().frame(height: 20).foregroundColor(SophosTheme.Colors.divider)

                        Text("Severity:")
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                        FilterPill(label: "All",    isSelected: selectedSeverity == nil)      { selectedSeverity = nil }
                        FilterPill(label: "High",   isSelected: selectedSeverity == "high")   { selectedSeverity = "high" }
                        FilterPill(label: "Medium", isSelected: selectedSeverity == "medium") { selectedSeverity = "medium" }
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
                    ErrorView(message: error) { Task { await load() } }
                } else if filtered.isEmpty {
                    Spacer()
                    VStack(spacing: SophosTheme.Spacing.sm) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 48))
                            .foregroundColor(SophosTheme.Colors.statusHealthy)
                        Text("No cases found")
                            .font(SophosTheme.Typography.headline())
                            .foregroundColor(SophosTheme.Colors.textPrimary)
                        Text("No cases match the selected filters.")
                            .font(SophosTheme.Typography.subheadline())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(filtered) { c in
                            Button { selectedCase = c } label: {
                                CaseListRow(sophosCase: c)
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
            prompt: "Search cases..."
        )
        .sheet(item: $selectedCase) { c in
            CaseDetailView(sophosCase: c)
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.fetchCases(severity: nil)
            cases = response.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Case list row

struct CaseListRow: View {
    let sophosCase: SophosCase

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {

            // Severity indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(SophosTheme.Colors.severityColor(sophosCase.severity))
                .frame(width: 4)
                .frame(minHeight: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(sophosCase.name ?? "Unnamed Case")
                    .font(SophosTheme.Typography.subheadline(.semibold))
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: SophosTheme.Spacing.xs) {
                    SeverityBadge(severity: sophosCase.severity)

                    CaseStatusBadge(status: sophosCase.status)

                    if sophosCase.managedBy?.lowercased() == "sophos" {
                        Text("MDR")
                            .font(SophosTheme.Typography.caption2(.semibold))
                            .foregroundColor(SophosTheme.Colors.sophosBlue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(SophosTheme.Colors.sophosBlue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: SophosTheme.Spacing.xs) {
                    if let detections = sophosCase.detectionCount, detections > 0 {
                        Label("\(detections) detections", systemImage: "waveform.path.ecg")
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                    }
                    Spacer()
                    if let date = sophosCase.updatedDate {
                        Text("Updated \(date, style: .relative) ago")
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(SophosTheme.Colors.textTertiary)
        }
        .padding(.vertical, SophosTheme.Spacing.xs)
    }
}

// MARK: - Case status badge

struct CaseStatusBadge: View {
    let status: String

    var color: Color {
        switch status.lowercased() {
        case "open":                       return SophosTheme.Colors.statusCritical
        case "inprogress", "in_progress":  return SophosTheme.Colors.statusWarning
        case "closed":                     return SophosTheme.Colors.statusHealthy
        default:                           return SophosTheme.Colors.textSecondary
        }
    }

    var label: String {
        switch status.lowercased() {
        case "inprogress", "in_progress": return "In Progress"
        default: return status.capitalized
        }
    }

    var body: some View {
        Text(label)
            .font(SophosTheme.Typography.caption2(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
