import SwiftUI

/// Run Live Discover queries against Sophos Central via Playwright backend.
struct LiveDiscoverView: View {
    @State private var query = ""
    @State private var results: PlaywrightService.LiveDiscoverResponse?
    @State private var loading = false
    @State private var error: String?
    @State private var selectedTemplate: QueryTemplate?

    private let pw = PlaywrightService.shared

    // Pre-built query templates
    private let templates: [QueryTemplate] = [
        QueryTemplate(name: "Running Processes", icon: "gearshape.2",
            query: "SELECT name, pid, cmdline, start_time FROM processes ORDER BY start_time DESC LIMIT 50"),
        QueryTemplate(name: "Network Connections", icon: "network",
            query: "SELECT pid, local_address, local_port, remote_address, remote_port, state FROM socket_events WHERE remote_address != '' LIMIT 50"),
        QueryTemplate(name: "Recent File Changes", icon: "doc.badge.clock",
            query: "SELECT target_path, action, time FROM file_events ORDER BY time DESC LIMIT 50"),
        QueryTemplate(name: "Installed Software", icon: "shippingbox",
            query: "SELECT name, version, install_date FROM programs ORDER BY install_date DESC LIMIT 50"),
        QueryTemplate(name: "User Logins", icon: "person.badge.key",
            query: "SELECT user, type, time, host FROM last WHERE time > datetime('now', '-7 days') ORDER BY time DESC LIMIT 50"),
        QueryTemplate(name: "Scheduled Tasks", icon: "clock.badge",
            query: "SELECT name, action, path, enabled, last_run_time FROM scheduled_tasks WHERE enabled = 1"),
        QueryTemplate(name: "Services", icon: "server.rack",
            query: "SELECT name, display_name, status, start_type, path FROM services WHERE status = 'RUNNING'"),
        QueryTemplate(name: "Browser Extensions", icon: "puzzlepiece",
            query: "SELECT name, identifier, version, browser_type, path FROM browser_plugins"),
    ]

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Query input
                VStack(spacing: SophosTheme.Spacing.sm) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(SophosTheme.Colors.textTertiary)
                        TextField("Enter SQL query or select a template...", text: $query, axis: .vertical)
                            .font(SophosTheme.Typography.footnote())
                            .foregroundStyle(SophosTheme.Colors.textPrimary)
                            .lineLimit(1...4)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(SophosTheme.Spacing.sm)
                    .background(SophosTheme.Colors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))

                    HStack {
                        Button {
                            Task { await runQuery() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                Text("Run Query")
                                    .font(SophosTheme.Typography.footnote(.semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, SophosTheme.Spacing.md)
                            .padding(.vertical, SophosTheme.Spacing.xs)
                            .background(SophosTheme.Colors.sophosBlue)
                            .clipShape(Capsule())
                        }
                        .disabled(query.isEmpty || loading)

                        Spacer()

                        if let results, let count = results.results?.count {
                            Text("\(count) rows")
                                .font(SophosTheme.Typography.caption2())
                                .foregroundStyle(SophosTheme.Colors.textSecondary)
                        }
                    }
                }
                .padding(SophosTheme.Spacing.md)

                Divider().background(SophosTheme.Colors.divider)

                // Content
                if loading {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Running query across endpoints...")
                            .font(SophosTheme.Typography.footnote())
                            .foregroundStyle(SophosTheme.Colors.textSecondary)
                    }
                    Spacer()
                } else if let error {
                    Spacer()
                    ContentUnavailableView {
                        Label("Query Failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                    Spacer()
                } else if let results, let rows = results.results?.rows, !rows.isEmpty {
                    // Results table
                    resultsView(columns: results.results?.columns ?? [], rows: rows)
                } else if results != nil {
                    Spacer()
                    ContentUnavailableView("No Results", systemImage: "tray",
                        description: Text("Query returned no data."))
                    Spacer()
                } else {
                    // Template picker
                    templatePicker
                }
            }
        }
        .navigationTitle("Live Discover")
    }

    // MARK: - Templates

    private var templatePicker: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SophosTheme.Spacing.sm) {
                ForEach(templates) { template in
                    Button {
                        query = template.query
                        selectedTemplate = template
                    } label: {
                        VStack(spacing: SophosTheme.Spacing.xs) {
                            Image(systemName: template.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(SophosTheme.Colors.sophosBlue)
                            Text(template.name)
                                .font(SophosTheme.Typography.caption2(.semibold))
                                .foregroundStyle(SophosTheme.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(SophosTheme.Spacing.md)
                        .background(SophosTheme.Colors.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.md))
                    }
                }
            }
            .padding(SophosTheme.Spacing.md)
        }
    }

    // MARK: - Results

    private func resultsView(columns: [String], rows: [[String: String]]) -> some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    ForEach(columns, id: \.self) { col in
                        Text(col)
                            .font(SophosTheme.Typography.caption2(.semibold))
                            .foregroundStyle(SophosTheme.Colors.textSecondary)
                            .frame(minWidth: 120, alignment: .leading)
                            .padding(SophosTheme.Spacing.xs)
                    }
                }
                .background(SophosTheme.Colors.backgroundCard2)

                Divider().background(SophosTheme.Colors.divider)

                // Rows
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    HStack(spacing: 0) {
                        ForEach(columns, id: \.self) { col in
                            Text(row[col] ?? "—")
                                .font(SophosTheme.Typography.caption2())
                                .foregroundStyle(SophosTheme.Colors.textPrimary)
                                .frame(minWidth: 120, alignment: .leading)
                                .padding(SophosTheme.Spacing.xs)
                        }
                    }
                    .background(idx % 2 == 0 ? Color.clear : SophosTheme.Colors.backgroundCard.opacity(0.5))
                }
            }
        }
    }

    // MARK: - Run

    private func runQuery() async {
        loading = true
        error = nil
        results = nil
        do {
            results = try await pw.runLiveDiscover(query: query)
            if let err = results?.error {
                error = err
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - Query Template

struct QueryTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let query: String
}
