import SwiftUI

// MARK: - Case Detail View

struct CaseDetailView: View {

    let sophosCase: SophosCase
    var onResolved: ((SophosCase) -> Void)? = nil
    var onUpdated: ((SophosCase) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var currentCase: SophosCase
    @State private var selectedTab: CaseTab = .overview

    // Overview / resolve state
    @State private var showResolveConfirm = false
    @State private var isResolving = false
    @State private var resolveError: String?

    // Edit sheet
    @State private var showEditSheet = false

    // Detections tab
    @State private var detections: [CaseDetection] = []
    @State private var detectionsLoading = false
    @State private var detectionsError: String?
    @State private var detectionsLoaded = false

    // MITRE tab
    @State private var mitreSummary: CaseMitreAttackSummary?
    @State private var mitreLoading = false
    @State private var mitreError: String?
    @State private var mitreLoaded = false

    private let api = SophosAPIService.shared

    enum CaseTab: String, CaseIterable {
        case overview   = "Overview"
        case detections = "Detections"
        case mitre      = "MITRE"
    }

    init(sophosCase: SophosCase,
         onResolved: ((SophosCase) -> Void)? = nil,
         onUpdated: ((SophosCase) -> Void)? = nil) {
        self.sophosCase = sophosCase
        self.onResolved = onResolved
        self.onUpdated = onUpdated
        _currentCase = State(initialValue: sophosCase)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented tab picker
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(CaseTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(SophosTheme.Spacing.md)
                    .background(SophosTheme.Colors.navigationBar)

                    switch selectedTab {
                    case .overview:   overviewContent
                    case .detections: detectionsContent
                    case .mitre:      mitreContent
                    }
                }
            }
            .navigationTitle("Case Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Edit button — self-managed cases only
                if currentCase.isSelfManaged {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { showEditSheet = true } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(SophosTheme.Colors.sophosBlue)
                        }
                    }
                }
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
                Button("Resolve Case") { Task { await resolveCase() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will mark the case as Resolved. Only self-managed cases can be closed via the API.")
            }
            .sheet(isPresented: $showEditSheet) {
                EditCaseSheet(sophosCase: currentCase) { updated in
                    currentCase = updated
                    onUpdated?(updated)
                    if updated.isResolved { onResolved?(updated) }
                }
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            switch newTab {
            case .detections where !detectionsLoaded:
                Task { await loadDetections() }
            case .mitre where !mitreLoaded:
                Task { await loadMitre() }
            default: break
            }
        }
    }

    // MARK: - Overview Tab

    @ViewBuilder
    private var overviewContent: some View {
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

                // Detection count — tappable shortcut to Detections tab
                if let count = currentCase.detectionCount, count > 0 {
                    Button { selectedTab = .detections } label: {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .foregroundColor(SophosTheme.Colors.sophosBlue)
                            Text("\(count) Detection\(count == 1 ? "" : "s") Associated")
                                .font(SophosTheme.Typography.subheadline(.semibold))
                                .foregroundColor(SophosTheme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(SophosTheme.Colors.textTertiary)
                        }
                        .padding(SophosTheme.Spacing.md)
                        .sophosCard()
                    }
                    .buttonStyle(.plain)
                }

                // Case details
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

                // Resolve action — self-managed, not yet resolved
                if currentCase.isSelfManaged && !currentCase.isResolved {
                    VStack(spacing: SophosTheme.Spacing.sm) {
                        Text("Actions")
                            .sophosSectionHeader()
                            .frame(maxWidth: .infinity, alignment: .leading)

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

                        Button { showResolveConfirm = true } label: {
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
                    Text("Case ID").sophosSectionHeader()
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

    // MARK: - Detections Tab

    @ViewBuilder
    private var detectionsContent: some View {
        if detectionsLoading {
            Spacer()
            ProgressView().tint(SophosTheme.Colors.sophosBlue)
            Spacer()
        } else if let error = detectionsError {
            ErrorView(message: error) { Task { await loadDetections() } }
        } else if detections.isEmpty {
            Spacer()
            VStack(spacing: SophosTheme.Spacing.sm) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 48))
                    .foregroundColor(SophosTheme.Colors.textTertiary)
                Text("No detections")
                    .font(SophosTheme.Typography.headline())
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                Text("No detections are linked to this case.")
                    .font(SophosTheme.Typography.subheadline())
                    .foregroundColor(SophosTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            Spacer()
        } else {
            List(detections) { detection in
                CaseDetectionRow(detection: detection)
                    .listRowBackground(SophosTheme.Colors.backgroundCard)
                    .listRowSeparatorTint(SophosTheme.Colors.divider)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(SophosTheme.Colors.backgroundPrimary)
            .refreshable { await loadDetections() }
        }
    }

    // MARK: - MITRE Tab

    @ViewBuilder
    private var mitreContent: some View {
        if mitreLoading {
            Spacer()
            ProgressView().tint(SophosTheme.Colors.sophosBlue)
            Spacer()
        } else if let error = mitreError {
            ErrorView(message: error) { Task { await loadMitre() } }
        } else if let summary = mitreSummary, let tactics = summary.tactics, !tactics.isEmpty {
            ScrollView {
                VStack(spacing: SophosTheme.Spacing.md) {
                    // Summary header
                    HStack {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundColor(SophosTheme.Colors.sophosBlue)
                        Text("MITRE ATT&CK Coverage")
                            .font(SophosTheme.Typography.subheadline(.semibold))
                            .foregroundColor(SophosTheme.Colors.textPrimary)
                        Spacer()
                        Text("\(tactics.count) tactic\(tactics.count == 1 ? "" : "s")")
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                    }
                    .padding(SophosTheme.Spacing.md)
                    .sophosCard()

                    ForEach(tactics) { tactic in
                        MitreTacticCard(tactic: tactic)
                    }

                    Spacer().frame(height: SophosTheme.Spacing.xl)
                }
                .padding(SophosTheme.Spacing.md)
            }
        } else {
            Spacer()
            VStack(spacing: SophosTheme.Spacing.sm) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 48))
                    .foregroundColor(SophosTheme.Colors.textTertiary)
                Text("No MITRE Data")
                    .font(SophosTheme.Typography.headline())
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                Text("No MITRE ATT&CK data is available for this case.")
                    .font(SophosTheme.Typography.subheadline())
                    .foregroundColor(SophosTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            Spacer()
        }
    }

    // MARK: - Async Actions

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

    private func loadDetections() async {
        detectionsLoading = true
        detectionsError = nil
        defer { detectionsLoading = false; detectionsLoaded = true }
        do {
            let response = try await api.fetchCaseDetections(caseId: currentCase.id)
            detections = response.items
        } catch {
            detectionsError = error.localizedDescription
        }
    }

    private func loadMitre() async {
        mitreLoading = true
        mitreError = nil
        defer { mitreLoading = false; mitreLoaded = true }
        do {
            mitreSummary = try await api.fetchCaseMitreAttackSummary(caseId: currentCase.id)
        } catch {
            mitreError = error.localizedDescription
        }
    }

    // MARK: - Display Helpers

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

// MARK: - Case Detection Row

struct CaseDetectionRow: View {
    let detection: CaseDetection

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {
            // Severity strip (severityToken converts Int → colour key)
            RoundedRectangle(cornerRadius: 2)
                .fill(SophosTheme.Colors.severityColor(detection.severityToken))
                .frame(width: 4)
                .frame(minHeight: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(detection.displayName)
                    .font(SophosTheme.Typography.subheadline(.semibold))
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: SophosTheme.Spacing.xs) {
                    SeverityBadge(severity: detection.severityToken)
                    if let host = detection.deviceName {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 10))
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                        Text(host)
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                    }
                }

                HStack(spacing: SophosTheme.Spacing.xs) {
                    let tactics = detection.mitreTacticNames
                    if !tactics.isEmpty {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 10))
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                        Text(tactics.joined(separator: " · "))
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let date = detection.detectedDate {
                        Text(date, style: .relative)
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                    }
                }
            }
        }
        .padding(.vertical, SophosTheme.Spacing.xs)
    }
}

// MARK: - MITRE Tactic Card

struct MitreTacticCard: View {
    let tactic: CaseMitreAttackSummary.Tactic

    var totalHits: Int {
        tactic.techniques?.reduce(0) { $0 + ($1.count ?? 0) } ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.sm) {

            // Tactic header
            HStack(spacing: SophosTheme.Spacing.xs) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(SophosTheme.Colors.sophosBlue)
                    .font(.system(size: 14))

                if let id = tactic.tacticId {
                    Text(id)
                        .font(SophosTheme.Typography.caption2(.semibold))
                        .foregroundColor(SophosTheme.Colors.sophosBlue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(SophosTheme.Colors.sophosBlue.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(tactic.name ?? "Unknown Tactic")
                    .font(SophosTheme.Typography.subheadline(.semibold))
                    .foregroundColor(SophosTheme.Colors.textPrimary)

                Spacer()

                if totalHits > 0 {
                    Text("\(totalHits) hit\(totalHits == 1 ? "" : "s")")
                        .font(SophosTheme.Typography.caption2(.semibold))
                        .foregroundColor(SophosTheme.Colors.statusWarning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(SophosTheme.Colors.statusWarning.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // Techniques
            if let techniques = tactic.techniques, !techniques.isEmpty {
                Divider().background(SophosTheme.Colors.divider)

                ForEach(techniques) { technique in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: SophosTheme.Spacing.xs) {
                            if let id = technique.techniqueId {
                                Text(id)
                                    .font(.custom("Menlo", size: 11))
                                    .foregroundColor(SophosTheme.Colors.textTertiary)
                            }
                            Text(technique.name ?? "Unknown Technique")
                                .font(SophosTheme.Typography.caption())
                                .foregroundColor(SophosTheme.Colors.textSecondary)

                            Spacer()

                            if let count = technique.count, count > 0 {
                                Text("\(count)")
                                    .font(SophosTheme.Typography.caption2(.semibold))
                                    .foregroundColor(SophosTheme.Colors.sophosBlue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(SophosTheme.Colors.sophosBlue.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        // Sub-techniques
                        if let subs = technique.subTechniques, !subs.isEmpty {
                            ForEach(subs) { sub in
                                HStack(spacing: SophosTheme.Spacing.xs) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.system(size: 9))
                                        .foregroundColor(SophosTheme.Colors.textTertiary)
                                    if let id = sub.subTechniqueId {
                                        Text(id)
                                            .font(.custom("Menlo", size: 10))
                                            .foregroundColor(SophosTheme.Colors.textTertiary)
                                    }
                                    Text(sub.name ?? "")
                                        .font(SophosTheme.Typography.caption2())
                                        .foregroundColor(SophosTheme.Colors.textTertiary)
                                    Spacer()
                                    if let count = sub.count, count > 0 {
                                        Text("\(count)")
                                            .font(SophosTheme.Typography.caption2())
                                            .foregroundColor(SophosTheme.Colors.textTertiary)
                                    }
                                }
                                .padding(.leading, SophosTheme.Spacing.md)
                            }
                        }
                    }
                    .padding(.leading, SophosTheme.Spacing.sm)
                }
            }
        }
        .padding(SophosTheme.Spacing.md)
        .sophosCard()
    }
}

// MARK: - Edit Case Sheet

struct EditCaseSheet: View {
    let sophosCase: SophosCase
    let onSaved: (SophosCase) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var overview: String
    @State private var selectedStatus: String
    @State private var selectedSeverity: String
    @State private var isSaving = false
    @State private var saveError: String?

    private let api = SophosAPIService.shared

    private let statuses: [(value: String, label: String)] = [
        ("new",            "New"),
        ("investigating",  "Investigating"),
        ("onHold",         "On Hold"),
        ("actionRequired", "Action Required"),
        ("resolved",       "Resolved")
    ]

    private let severities: [(value: String, label: String)] = [
        ("critical",      "Critical"),
        ("high",          "High"),
        ("medium",        "Medium"),
        ("low",           "Low"),
        ("informational", "Informational")
    ]

    init(sophosCase: SophosCase, onSaved: @escaping (SophosCase) -> Void) {
        self.sophosCase = sophosCase
        self.onSaved = onSaved
        _name             = State(initialValue: sophosCase.name ?? "")
        _overview         = State(initialValue: sophosCase.overview ?? "")
        _selectedStatus   = State(initialValue: sophosCase.status)
        _selectedSeverity = State(initialValue: sophosCase.severity)
    }

    var hasChanges: Bool {
        name     != (sophosCase.name ?? "")     ||
        overview != (sophosCase.overview ?? "") ||
        selectedStatus   != sophosCase.status   ||
        selectedSeverity != sophosCase.severity
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

                Form {
                    Section("Case Name") {
                        TextField("Enter case name", text: $name)
                            .foregroundColor(SophosTheme.Colors.textPrimary)
                    }

                    Section("Status") {
                        Picker("Status", selection: $selectedStatus) {
                            ForEach(statuses, id: \.value) { s in
                                Text(s.label).tag(s.value)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(SophosTheme.Colors.sophosBlue)
                    }

                    Section("Severity") {
                        Picker("Severity", selection: $selectedSeverity) {
                            ForEach(severities, id: \.value) { s in
                                Text(s.label).tag(s.value)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(SophosTheme.Colors.sophosBlue)
                    }

                    Section("Summary") {
                        TextEditor(text: $overview)
                            .frame(minHeight: 100)
                            .foregroundColor(SophosTheme.Colors.textPrimary)
                    }

                    if let err = saveError {
                        Section {
                            HStack(spacing: SophosTheme.Spacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(SophosTheme.Colors.statusCritical)
                                Text(err)
                                    .font(SophosTheme.Typography.caption())
                                    .foregroundColor(SophosTheme.Colors.statusCritical)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(SophosTheme.Colors.sophosBlue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(SophosTheme.Colors.sophosBlue)
                                .scaleEffect(0.85)
                        } else {
                            Text("Save")
                                .bold()
                                .foregroundColor(hasChanges ? SophosTheme.Colors.sophosBlue : SophosTheme.Colors.textTertiary)
                        }
                    }
                    .disabled(isSaving || !hasChanges || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            // Only send fields that actually changed
            let request = UpdateCaseRequest(
                status:   selectedStatus   != sophosCase.status           ? selectedStatus   : nil,
                severity: selectedSeverity != sophosCase.severity         ? selectedSeverity : nil,
                name:     name     != (sophosCase.name     ?? "")         ? name             : nil,
                overview: overview != (sophosCase.overview ?? "")         ? overview         : nil
            )
            let updated = try await api.updateCase(id: sophosCase.id, request: request)
            onSaved(updated)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
