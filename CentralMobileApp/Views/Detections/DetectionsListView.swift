import SwiftUI

struct DetectionsListView: View {

    @State private var detections: [SophosDetection] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedSeverity: String? = nil
    @State private var searchText = ""
    @State private var selectedDetection: SophosDetection?

    private let api = SophosAPIService.shared
    private let severities = ["All", "Critical", "High", "Medium", "Low", "Info"]

    private var filtered: [SophosDetection] {
        var list = detections
        if let sev = selectedSeverity {
            list = list.filter { $0.severityLabel.lowercased() == sev.lowercased() }
        }
        if !searchText.isEmpty {
            list = list.filter {
                ($0.detectionRule ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.detectionRuleDescription ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.device?.entity ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.attackType ?? "").localizedCaseInsensitiveContains(searchText)
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
                    VStack(spacing: SophosTheme.Spacing.sm) {
                        ProgressView().tint(SophosTheme.Colors.sophosBlue)
                        Text("Querying detections…")
                            .font(SophosTheme.Typography.footnote())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                    }
                    Spacer()
                } else if let error = errorMessage {
                    ErrorView(message: error) { Task { await load() } }
                } else if filtered.isEmpty {
                    Spacer()
                    VStack(spacing: SophosTheme.Spacing.sm) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 48))
                            .foregroundColor(SophosTheme.Colors.statusHealthy)
                        Text("No detections found")
                            .font(SophosTheme.Typography.headline())
                            .foregroundColor(SophosTheme.Colors.textPrimary)
                        Text("No detections match the selected filter.")
                            .font(SophosTheme.Typography.subheadline())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(filtered) { detection in
                            Button { selectedDetection = detection } label: {
                                DetectionListRow(detection: detection)
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
            prompt: "Search detections…"
        )
        .sheet(item: $selectedDetection) { detection in
            DetectionDetailSheet(detection: detection)
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            detections = try await api.fetchDetections(pageSize: 100)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Detection list row

struct DetectionListRow: View {
    let detection: SophosDetection

    private var severityColor: Color {
        switch detection.severityLabel {
        case "Critical": return SophosTheme.Colors.statusCritical
        case "High":     return SophosTheme.Colors.statusWarning
        case "Medium":   return .orange
        case "Low":      return SophosTheme.Colors.textSecondary
        default:         return SophosTheme.Colors.sophosBlue
        }
    }

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {

            // Severity bar
            RoundedRectangle(cornerRadius: 2)
                .fill(severityColor)
                .frame(width: 4)
                .frame(minHeight: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(detection.detectionRule ?? detection.attackType ?? "Detection")
                    .font(SophosTheme.Typography.subheadline(.semibold))
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: SophosTheme.Spacing.xs) {
                    // Severity pill
                    Text(detection.severityLabel)
                        .font(SophosTheme.Typography.caption2(.semibold))
                        .foregroundColor(severityColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(severityColor.opacity(0.15))
                        .clipShape(Capsule())

                    if let device = detection.device?.entity {
                        Text(device)
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    if let tactic = detection.mitreTactics.first {
                        Text("·")
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                        Text(tactic)
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                if let date = detection.generatedDate {
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

// MARK: - Detection detail sheet

struct DetectionDetailSheet: View {
    let detection: SophosDetection
    @Environment(\.dismiss) private var dismiss

    private var severityColor: Color {
        switch detection.severityLabel {
        case "Critical": return SophosTheme.Colors.statusCritical
        case "High":     return SophosTheme.Colors.statusWarning
        case "Medium":   return .orange
        case "Low":      return SophosTheme.Colors.textSecondary
        default:         return SophosTheme.Colors.sophosBlue
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: SophosTheme.Spacing.md) {

                        // Severity header
                        HStack {
                            Text(detection.severityLabel)
                                .font(SophosTheme.Typography.subheadline(.semibold))
                                .foregroundColor(severityColor)
                                .padding(.horizontal, SophosTheme.Spacing.sm)
                                .padding(.vertical, SophosTheme.Spacing.xxs)
                                .background(severityColor.opacity(0.15))
                                .clipShape(Capsule())
                            if let count = detection.count, count > 1 {
                                Text("\(count)× occurrences")
                                    .font(SophosTheme.Typography.footnote())
                                    .foregroundColor(SophosTheme.Colors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, SophosTheme.Spacing.md)

                        // Detection info card
                        VStack(alignment: .leading, spacing: 0) {
                            detailSectionHeader("Detection")
                            if let rule = detection.detectionRule {
                                DetailRow(label: "Rule", value: rule)
                                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                            }
                            if let desc = detection.detectionRuleDescription {
                                DetailRow(label: "Description", value: desc)
                                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                            }
                            if let attack = detection.attackType {
                                DetailRow(label: "Attack Type", value: attack)
                                Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                            }
                            if let detAttack = detection.detectionAttack {
                                DetailRow(label: "Category", value: detAttack)
                            }
                        }
                        .padding(SophosTheme.Spacing.md)
                        .sophosCard()
                        .padding(.horizontal, SophosTheme.Spacing.md)

                        // Device card
                        if let device = detection.device {
                            VStack(alignment: .leading, spacing: 0) {
                                detailSectionHeader("Device")
                                if let entity = device.entity {
                                    DetailRow(label: "Hostname", value: entity)
                                    Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                                }
                                if let type = device.type {
                                    DetailRow(label: "Type", value: type.capitalized)
                                    Divider().background(SophosTheme.Colors.divider).padding(.leading, SophosTheme.Spacing.md)
                                }
                                if let id = device.id {
                                    DetailRow(label: "Device ID", value: String(id.prefix(8)) + "…")
                                }
                            }
                            .padding(SophosTheme.Spacing.md)
                            .sophosCard()
                            .padding(.horizontal, SophosTheme.Spacing.md)
                        }

                        // MITRE ATT&CK card
                        if !detection.mitreTactics.isEmpty {
                            VStack(alignment: .leading, spacing: SophosTheme.Spacing.sm) {
                                detailSectionHeader("MITRE ATT&CK")
                                ForEach(detection.mitreTactics, id: \.self) { tactic in
                                    HStack(spacing: SophosTheme.Spacing.xs) {
                                        Image(systemName: "shield.lefthalf.filled")
                                            .font(.system(size: 12))
                                            .foregroundColor(SophosTheme.Colors.sophosBlue)
                                        Text(tactic)
                                            .font(SophosTheme.Typography.subheadline())
                                            .foregroundColor(SophosTheme.Colors.textPrimary)
                                    }
                                }
                            }
                            .padding(SophosTheme.Spacing.md)
                            .sophosCard()
                            .padding(.horizontal, SophosTheme.Spacing.md)
                        }

                        // Timing card
                        if let date = detection.generatedDate {
                            VStack(alignment: .leading, spacing: 0) {
                                detailSectionHeader("Timing")
                                DetailRow(label: "Detected", value: date.formatted(date: .abbreviated, time: .standard))
                            }
                            .padding(SophosTheme.Spacing.md)
                            .sophosCard()
                            .padding(.horizontal, SophosTheme.Spacing.md)
                        }

                        Spacer().frame(height: SophosTheme.Spacing.xl)
                    }
                    .padding(.top, SophosTheme.Spacing.sm)
                }
            }
            .navigationTitle(detection.detectionRule ?? "Detection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(SophosTheme.Colors.sophosBlue)
                }
            }
        }
    }

    private func detailSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(SophosTheme.Typography.caption2(.semibold))
            .foregroundColor(SophosTheme.Colors.textTertiary)
            .padding(.bottom, SophosTheme.Spacing.xs)
    }
}
