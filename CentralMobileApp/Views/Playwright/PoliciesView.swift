import SwiftUI

/// Displays Sophos Central policies fetched via Playwright backend.
struct PoliciesView: View {
    @State private var policies: [PlaywrightService.PolicyItem] = []
    @State private var loading = false
    @State private var error: String?

    private let pw = PlaywrightService.shared

    var body: some View {
        Group {
            if loading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading policies from Sophos Central…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if policies.isEmpty {
                ContentUnavailableView("No Policies", systemImage: "shield.slash")
            } else {
                List(policies) { policy in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(policy.name)
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Score: \(policy.type)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        statusBadge(policy.status)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Health Check")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadPolicies() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(loading)
            }
        }
        .task { await loadPolicies() }
    }

    private func loadPolicies() async {
        loading = true
        error = nil
        do {
            let response = try await pw.fetchPolicies()
            policies = response.policies ?? []
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    @ViewBuilder
    private func statusBadge(_ status: String) -> some View {
        let isHealthy = status.lowercased() == "healthy"
        Text(status)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isHealthy ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
            .foregroundStyle(isHealthy ? .green : .orange)
            .clipShape(Capsule())
    }
}
