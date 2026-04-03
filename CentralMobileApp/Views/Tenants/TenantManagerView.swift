import SwiftUI
import SwiftData

struct TenantManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedTenant.name) private var tenants: [SavedTenant]
    @State private var showAddSheet = false

    private let keychain = KeychainService.shared

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            if tenants.isEmpty {
                ContentUnavailableView {
                    Label("No Tenants", systemImage: "building.2")
                } description: {
                    Text("Add Sophos Central tenants to manage multiple organizations.")
                } actions: {
                    Button("Add Tenant") { showAddSheet = true }
                        .buttonStyle(.borderedProminent)
                        .tint(SophosTheme.Colors.sophosBlue)
                }
            } else {
                List {
                    ForEach(tenants) { tenant in
                        TenantRow(tenant: tenant, onSwitch: { switchTo(tenant) })
                            .listRowBackground(SophosTheme.Colors.backgroundCard)
                    }
                    .onDelete(perform: deleteTenants)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Tenants")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTenantView()
        }
    }

    private func switchTo(_ tenant: SavedTenant) {
        // Deactivate all
        for t in tenants { t.isActive = false }
        // Activate selected
        tenant.isActive = true

        // Update keychain with this tenant's credentials
        keychain.save(tenant.clientId, for: .clientId)
        keychain.save(tenant.clientSecret, for: .clientSecret)
        keychain.save(tenant.tenantId, for: .tenantId)
        keychain.save(tenant.dataRegionURL, for: .dataRegionURL)

        // Clear token so it re-authenticates
        keychain.delete(.accessToken)
        keychain.delete(.tokenExpiry)
    }

    private func deleteTenants(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tenants[index])
        }
    }
}

// MARK: - Tenant Row

struct TenantRow: View {
    let tenant: SavedTenant
    let onSwitch: () -> Void

    var body: some View {
        Button(action: onSwitch) {
            HStack(spacing: SophosTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(tenant.name)
                            .font(SophosTheme.Typography.body(.semibold))
                            .foregroundStyle(SophosTheme.Colors.textPrimary)
                        if tenant.isActive {
                            Text("Active")
                                .font(SophosTheme.Typography.caption2(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(SophosTheme.Colors.statusHealthy.opacity(0.15))
                                .foregroundStyle(SophosTheme.Colors.statusHealthy)
                                .clipShape(Capsule())
                        }
                    }

                    Text(tenant.tenantId.prefix(12) + "...")
                        .font(SophosTheme.Typography.caption2())
                        .foregroundStyle(SophosTheme.Colors.textTertiary)

                    HStack(spacing: SophosTheme.Spacing.sm) {
                        if let score = tenant.lastHealthScore {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(score >= 80 ? SophosTheme.Colors.statusHealthy :
                                          score >= 50 ? SophosTheme.Colors.statusWarning :
                                          SophosTheme.Colors.statusCritical)
                                    .frame(width: 8, height: 8)
                                Text("Score: \(score)")
                                    .font(SophosTheme.Typography.caption2())
                                    .foregroundStyle(SophosTheme.Colors.textSecondary)
                            }
                        }
                        if let alerts = tenant.lastAlertCount, alerts > 0 {
                            Text("\(alerts) alerts")
                                .font(SophosTheme.Typography.caption2())
                                .foregroundStyle(SophosTheme.Colors.statusWarning)
                        }
                    }
                }

                Spacer()

                if tenant.isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SophosTheme.Colors.statusHealthy)
                } else {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(SophosTheme.Colors.textTertiary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Add Tenant

struct AddTenantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

                List {
                    Section("Tenant Name") {
                        TextField("e.g. Acme Corp", text: $name)
                            .font(SophosTheme.Typography.body())
                    }
                    .listRowBackground(SophosTheme.Colors.backgroundCard)

                    Section("API Credentials") {
                        TextField("Client ID", text: $clientId)
                            .font(SophosTheme.Typography.body())
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        SecureField("Client Secret", text: $clientSecret)
                            .font(SophosTheme.Typography.body())
                    }
                    .listRowBackground(SophosTheme.Colors.backgroundCard)

                    if let error {
                        Section {
                            Text(error)
                                .foregroundStyle(SophosTheme.Colors.statusCritical)
                                .font(SophosTheme.Typography.footnote())
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Tenant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await addTenant() }
                    }
                    .disabled(name.isEmpty || clientId.isEmpty || clientSecret.isEmpty || saving)
                }
            }
        }
    }

    private func addTenant() async {
        saving = true
        error = nil

        do {
            // Authenticate to get tenant ID and data region
            let auth = AuthService.shared
            try await auth.authenticate(clientId: clientId, clientSecret: clientSecret)

            let keychain = KeychainService.shared
            let tenantId = keychain.read(.tenantId) ?? ""
            let dataRegion = keychain.read(.dataRegionURL) ?? ""

            let tenant = SavedTenant(
                tenantId: tenantId,
                name: name,
                dataRegionURL: dataRegion,
                clientId: clientId,
                clientSecret: clientSecret
            )
            modelContext.insert(tenant)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        saving = false
    }
}
