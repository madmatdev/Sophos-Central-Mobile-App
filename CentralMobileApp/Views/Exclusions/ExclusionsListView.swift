import SwiftUI

struct ExclusionsListView: View {
    @State private var exclusions: [SophosExclusion] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showAddSheet = false

    private let api = SophosAPIService.shared

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            Group {
                if loading && exclusions.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error, exclusions.isEmpty {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else if exclusions.isEmpty {
                    ContentUnavailableView("No Exclusions", systemImage: "shield.slash",
                        description: Text("No scanning exclusions configured."))
                } else {
                    List {
                        ForEach(exclusions) { exclusion in
                            ExclusionRow(exclusion: exclusion)
                                .listRowBackground(SophosTheme.Colors.backgroundCard)
                        }
                        .onDelete(perform: deleteExclusion)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Exclusions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button {
                        Task { await loadExclusions() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(loading)

                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddExclusionView { newExclusion in
                exclusions.insert(newExclusion, at: 0)
            }
        }
        .task { await loadExclusions() }
    }

    private func loadExclusions() async {
        loading = true
        error = nil
        do {
            let response = try await api.fetchExclusions()
            exclusions = response.items
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func deleteExclusion(at offsets: IndexSet) {
        let toDelete = offsets.map { exclusions[$0] }
        exclusions.remove(atOffsets: offsets)
        Task {
            for exc in toDelete {
                try? await api.deleteExclusion(id: exc.id)
            }
        }
    }
}

// MARK: - Exclusion Row

struct ExclusionRow: View {
    let exclusion: SophosExclusion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exclusion.value ?? "Unknown")
                .font(SophosTheme.Typography.body(.semibold))
                .foregroundStyle(SophosTheme.Colors.textPrimary)
                .lineLimit(2)

            HStack(spacing: SophosTheme.Spacing.sm) {
                if let type = exclusion.type {
                    Label(type.capitalized, systemImage: typeIcon(type))
                        .font(SophosTheme.Typography.caption2())
                        .foregroundStyle(SophosTheme.Colors.textSecondary)
                }
                if let scan = exclusion.scanMode {
                    Text(scan)
                        .font(SophosTheme.Typography.caption2())
                        .foregroundStyle(SophosTheme.Colors.textTertiary)
                }
            }

            if let desc = exclusion.description, !desc.isEmpty {
                Text(desc)
                    .font(SophosTheme.Typography.footnote())
                    .foregroundStyle(SophosTheme.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func typeIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "path":      return "folder"
        case "process":   return "gearshape.2"
        case "web":       return "globe"
        case "pua":       return "app.badge"
        case "behavioral": return "brain"
        default:          return "shield"
        }
    }
}

// MARK: - Add Exclusion

struct AddExclusionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var type = "path"
    @State private var value = ""
    @State private var description = ""
    @State private var saving = false

    let onSave: (SophosExclusion) -> Void
    private let api = SophosAPIService.shared

    private let types = ["path", "process", "web", "pua", "behavioral", "amsi"]

    var body: some View {
        NavigationStack {
            ZStack {
                SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

                List {
                    Section("Type") {
                        Picker("Exclusion Type", selection: $type) {
                            ForEach(types, id: \.self) { t in
                                Text(t.capitalized).tag(t)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .listRowBackground(SophosTheme.Colors.backgroundCard)

                    Section("Value") {
                        TextField("e.g. C:\\Program Files\\MyApp\\", text: $value)
                            .font(SophosTheme.Typography.body())
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .listRowBackground(SophosTheme.Colors.backgroundCard)

                    Section("Description (optional)") {
                        TextField("Why this exclusion exists", text: $description)
                            .font(SophosTheme.Typography.body())
                    }
                    .listRowBackground(SophosTheme.Colors.backgroundCard)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Exclusion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(value.isEmpty || saving)
                }
            }
        }
    }

    private func save() async {
        saving = true
        do {
            let exc = try await api.createExclusion(
                type: type,
                value: value,
                description: description.isEmpty ? nil : description
            )
            onSave(exc)
            dismiss()
        } catch {
            // TODO: show error
        }
        saving = false
    }
}
