import SwiftUI

struct DevicesListView: View {

    @State private var viewModel = DevicesViewModel()
    @State private var selectedEndpoint: SophosEndpoint?

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {

                // Filter bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SophosTheme.Spacing.xs) {
                        FilterPill(label: "All",         isSelected: viewModel.filterHealth == nil)          { viewModel.filterHealth = nil }
                        FilterPill(label: "Healthy",     isSelected: viewModel.filterHealth == "good")       { viewModel.filterHealth = "good" }
                        FilterPill(label: "Suspicious",  isSelected: viewModel.filterHealth == "suspicious") { viewModel.filterHealth = "suspicious" }
                        FilterPill(label: "At Risk",     isSelected: viewModel.filterHealth == "bad")        { viewModel.filterHealth = "bad" }
                    }
                    .padding(.horizontal, SophosTheme.Spacing.md)
                    .padding(.vertical, SophosTheme.Spacing.sm)
                }
                .background(SophosTheme.Colors.navigationBar)

                // Summary bar
                if !viewModel.endpoints.isEmpty {
                    HStack {
                        Text("\(viewModel.filtered.count) device\(viewModel.filtered.count == 1 ? "" : "s")")
                            .font(SophosTheme.Typography.footnote())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                        Spacer()
                        HStack(spacing: SophosTheme.Spacing.xs) {
                            Circle().fill(SophosTheme.Colors.statusHealthy).frame(width: 6, height: 6)
                            Text("\(viewModel.healthyEndpointCount) healthy")
                                .font(SophosTheme.Typography.caption())
                                .foregroundColor(SophosTheme.Colors.textSecondary)
                            if viewModel.unhealthyEndpointCount > 0 {
                                Circle().fill(SophosTheme.Colors.statusCritical).frame(width: 6, height: 6)
                                Text("\(viewModel.unhealthyEndpointCount) at risk")
                                    .font(SophosTheme.Typography.caption())
                                    .foregroundColor(SophosTheme.Colors.statusCritical)
                            }
                        }
                    }
                    .padding(.horizontal, SophosTheme.Spacing.md)
                    .padding(.vertical, SophosTheme.Spacing.xs)
                    .background(SophosTheme.Colors.backgroundOverlay)
                }

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(SophosTheme.Colors.sophosBlue)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) { Task { await viewModel.load() } }
                } else if viewModel.filtered.isEmpty {
                    Spacer()
                    VStack(spacing: SophosTheme.Spacing.sm) {
                        Image(systemName: "laptopcomputer.slash")
                            .font(.system(size: 48))
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                        Text("No devices found")
                            .font(SophosTheme.Typography.headline())
                            .foregroundColor(SophosTheme.Colors.textPrimary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.filtered) { endpoint in
                            Button { selectedEndpoint = endpoint } label: {
                                DeviceListRow(
                                    endpoint: endpoint,
                                    isActing: viewModel.actionInProgress == endpoint.id
                                )
                            }
                            .listRowBackground(SophosTheme.Colors.backgroundCard)
                            .listRowSeparatorTint(SophosTheme.Colors.divider)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(SophosTheme.Colors.backgroundPrimary)
                    .refreshable { await viewModel.load() }
                }
            }
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search devices or users..."
        )
        .sheet(item: $selectedEndpoint) { endpoint in
            DeviceDetailView(endpoint: endpoint, viewModel: viewModel)
        }
        .task { await viewModel.load() }
    }
}

// MARK: - Device list row

struct DeviceListRow: View {
    let endpoint: SophosEndpoint
    let isActing: Bool

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {

            // Platform icon with health indicator
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: endpoint.platformIcon)
                    .font(.system(size: 22))
                    .foregroundColor(SophosTheme.Colors.textSecondary)
                    .frame(width: 32, height: 32)

                Circle()
                    .fill(SophosTheme.Colors.healthColor(endpoint.health?.overall ?? "unknown"))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(SophosTheme.Colors.backgroundCard, lineWidth: 1.5))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(endpoint.hostname ?? "Unknown Device")
                        .font(SophosTheme.Typography.subheadline(.semibold))
                        .foregroundColor(SophosTheme.Colors.textPrimary)
                    if endpoint.tamperProtectionEnabled == true {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 10))
                            .foregroundColor(SophosTheme.Colors.sophosBlue)
                    }
                }

                if let person = endpoint.associatedPerson?.name {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text(person)
                    }
                    .font(SophosTheme.Typography.caption())
                    .foregroundColor(SophosTheme.Colors.textSecondary)
                }

                HStack(spacing: SophosTheme.Spacing.xs) {
                    if let os = endpoint.os?.name {
                        Text(os)
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                    }
                    if let ip = endpoint.ipv4Addresses?.first {
                        Text("·").foregroundColor(SophosTheme.Colors.textTertiary)
                        Text(ip)
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            if isActing {
                ProgressView().tint(SophosTheme.Colors.sophosBlue).scaleEffect(0.7)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(SophosTheme.Colors.textTertiary)
            }
        }
        .padding(.vertical, SophosTheme.Spacing.xs)
    }
}
