import SwiftUI

// MARK: - API status / severity constants (Sophos Cases v1)

private enum CaseStatus: String, CaseIterable {
    case all           = ""
    case new           = "new"
    case investigating = "investigating"
    case onHold        = "onHold"
    case actionRequired = "actionRequired"
    case resolved      = "resolved"

    var label: String {
        switch self {
        case .all:            return "All"
        case .new:            return "New"
        case .investigating:  return "Investigating"
        case .onHold:         return "On Hold"
        case .actionRequired: return "Action Required"
        case .resolved:       return "Resolved"
        }
    }

    var color: Color {
        switch self {
        case .all:            return SophosTheme.Colors.textSecondary
        case .new:            return SophosTheme.Colors.statusCritical
        case .investigating:  return SophosTheme.Colors.statusWarning
        case .onHold:         return SophosTheme.Colors.textSecondary
        case .actionRequired: return SophosTheme.Colors.statusCritical
        case .resolved:       return SophosTheme.Colors.statusHealthy
        }
    }
}

private enum CaseSeverity: String, CaseIterable {
    case all          = ""
    case critical     = "critical"
    case high         = "high"
    case medium       = "medium"
    case low          = "low"
    case informational = "informational"

    var label: String {
        switch self {
        case .all:           return "All"
        case .critical:      return "Critical"
        case .high:          return "High"
        case .medium:        return "Medium"
        case .low:           return "Low"
        case .informational: return "Info"
        }
    }
}

// MARK: - View

struct CasesListView: View {

    @State private var cases: [SophosCase] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedStatus: CaseStatus   = .all
    @State private var selectedSeverity: CaseSeverity = .all
    @State private var searchText = ""
    @State private var selectedCase: SophosCase?

    // Close-case action state
    @State private var caseToClose: SophosCase?
    @State private var showCloseConfirm = false
    @State private var isClosing = false
    @State private var closeResult: CloseResult?

    private let api = SophosAPIService.shared

    private var filtered: [SophosCase] {
        var list = cases
        if selectedStatus != .all {
            list = list.filter { $0.status == selectedStatus.rawValue }
        }
        if selectedSeverity != .all {
            list = list.filter { $0.severity.lowercased() == selectedSeverity.rawValue }
        }
        if !searchText.isEmpty {
            list = list.filter {
                ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.overview ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.type ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {

                // Close result banner
                if let result = closeResult {
                    CloseResultBanner(result: result) { closeResult = nil }
                }

                // Filter bar — Status row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SophosTheme.Spacing.xs) {
                        Text("Status:")
                            .font(SophosTheme.Typography.caption2(.semibold))
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                            .fixedSize()

                        ForEach(CaseStatus.allCases, id: \.self) { s in
                            FilterPill(label: s.label,
                                       isSelected: selectedStatus == s) {
                                selectedStatus = s
                                Task { await load() }
                            }
                        }

                        Divider().frame(height: 18).foregroundColor(SophosTheme.Colors.divider)

                        Text("Severity:")
                            .font(SophosTheme.Typography.caption2(.semibold))
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                            .fixedSize()

                        ForEach(CaseSeverity.allCases, id: \.self) { s in
                            FilterPill(label: s.label,
                                       isSelected: selectedSeverity == s) {
                                selectedSeverity = s
                                Task { await load() }
                            }
                        }
                    }
                    .padding(.horizontal, SophosTheme.Spacing.md)
                    .padding(.vertical, SophosTheme.Spacing.sm)
                }
                .background(SophosTheme.Colors.navigationBar)

                // Results summary
                if !cases.isEmpty && !isLoading {
                    HStack {
                        Text("\(filtered.count) case\(filtered.count == 1 ? "" : "s")")
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                        Spacer()
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
                            // Swipe-to-close for self-managed, non-resolved cases
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if c.isSelfManaged && !c.isResolved {
                                    Button(role: .destructive) {
                                        caseToClose = c
                                        showCloseConfirm = true
                                    } label: {
                                        Label("Resolve", systemImage: "checkmark.circle")
                                    }
                                    .tint(SophosTheme.Colors.statusHealthy)
                                }
                            }
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
            prompt: "Search cases…"
        )
        .confirmationDialog(
            "Resolve \"\(caseToClose?.name ?? "this case")\"?",
            isPresented: $showCloseConfirm,
            titleVisibility: .visible
        ) {
            Button("Resolve Case") {
                guard let c = caseToClose else { return }
                Task { await closeCase(c) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will mark the case as Resolved. This action applies only to self-managed cases.")
        }
        .sheet(item: $selectedCase) { c in
            CaseDetailView(
                sophosCase: c,
                onResolved: { resolvedCase in
                    if let idx = cases.firstIndex(where: { $0.id == resolvedCase.id }) {
                        cases[idx] = resolvedCase
                    }
                },
                onUpdated: { updatedCase in
                    if let idx = cases.firstIndex(where: { $0.id == updatedCase.id }) {
                        cases[idx] = updatedCase
                    }
                }
            )
        }
        .task { await load() }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let statuses   = selectedStatus   == .all ? [] : [selectedStatus.rawValue]
            let severities = selectedSeverity == .all ? [] : [selectedSeverity.rawValue]
            let response = try await api.fetchCases(statuses: statuses, severities: severities)
            cases = response.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func closeCase(_ sophosCase: SophosCase) async {
        isClosing = true
        defer { isClosing = false }
        do {
            let updated = try await api.updateCase(
                id: sophosCase.id,
                request: UpdateCaseRequest(status: "resolved")
            )
            // Replace in list
            if let idx = cases.firstIndex(where: { $0.id == sophosCase.id }) {
                cases[idx] = updated
            }
            closeResult = CloseResult(caseName: sophosCase.name ?? "Case", success: true)
        } catch {
            closeResult = CloseResult(caseName: sophosCase.name ?? "Case", success: false, error: error.localizedDescription)
        }
    }
}

// MARK: - Close result model

struct CloseResult {
    let caseName: String
    let success: Bool
    var error: String? = nil
}

// MARK: - Close result banner

private struct CloseResultBanner: View {
    let result: CloseResult
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(result.success ? SophosTheme.Colors.statusHealthy : SophosTheme.Colors.statusCritical)

            Text(result.success
                 ? "\"\(result.caseName)\" resolved"
                 : "Failed to resolve: \(result.error ?? "Unknown error")")
                .font(SophosTheme.Typography.subheadline(.semibold))
                .foregroundColor(result.success ? SophosTheme.Colors.statusHealthy : SophosTheme.Colors.statusCritical)
                .lineLimit(2)

            Spacer()

            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SophosTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, SophosTheme.Spacing.md)
        .padding(.vertical, SophosTheme.Spacing.sm)
        .background(
            (result.success ? SophosTheme.Colors.statusHealthy : SophosTheme.Colors.statusCritical)
                .opacity(0.12)
        )
    }
}

// MARK: - Case list row

struct CaseListRow: View {
    let sophosCase: SophosCase

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {

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

// MARK: - Case status badge (corrected for Sophos Cases v1 API values)

struct CaseStatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "new":            return SophosTheme.Colors.statusCritical
        case "investigating":  return SophosTheme.Colors.statusWarning
        case "onHold":         return SophosTheme.Colors.textSecondary
        case "actionRequired": return SophosTheme.Colors.statusCritical
        case "resolved":       return SophosTheme.Colors.statusHealthy
        default:               return SophosTheme.Colors.textSecondary
        }
    }

    var label: String {
        switch status {
        case "new":            return "New"
        case "investigating":  return "Investigating"
        case "onHold":         return "On Hold"
        case "actionRequired": return "Action Required"
        case "resolved":       return "Resolved"
        default:               return status.capitalized
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
