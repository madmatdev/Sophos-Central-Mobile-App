import SwiftUI

/// Shows Playwright backend connection status and Sophos Central session health.
struct PlaywrightStatusView: View {
    @State private var health: PlaywrightService.HealthResponse?
    @State private var session: PlaywrightService.SessionStatus?
    @State private var loading = false
    @State private var error: String?

    private let pw = PlaywrightService.shared

    var body: some View {
        List {
            Section("Backend") {
                if let health {
                    row("Service", health.service ?? "unknown")
                    row("Session File", health.session ?? "unknown")
                    row("Browser", health.browser ?? "unknown")
                    statusRow("Status", health.ok)
                } else if loading {
                    ProgressView()
                } else if let error {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }

            Section("Sophos Central Session") {
                if let session {
                    statusRow("Authenticated", session.ok)
                    row("Status", session.status)
                    if let title = session.title {
                        row("Page", title)
                    }
                    if let msg = session.message {
                        Text(msg).foregroundStyle(.orange).font(.caption)
                    }
                } else if loading {
                    ProgressView()
                }
            }

            Section {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .navigationTitle("Playwright Backend")
        .task { await refresh() }
    }

    private func refresh() async {
        loading = true
        error = nil
        do {
            health = try await pw.checkHealth()
            session = try await pw.sessionStatus()
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }

    private func statusRow(_ label: String, _ ok: Bool) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
            Text(ok ? "Connected" : "Disconnected")
                .foregroundStyle(ok ? .green : .red)
                .fontWeight(.medium)
        }
    }
}
