import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class DashboardViewModel {

    // MARK: - State

    var accountHealth: AccountHealthResponse?
    var alerts: [SophosAlert] = []
    var endpoints: [SophosEndpoint] = []
    var cases: [SophosCase] = []

    var isLoadingHealth    = false
    var isLoadingAlerts    = false
    var isLoadingEndpoints = false
    var isLoadingCases     = false

    var healthError:    String?
    var alertsError:    String?
    var endpointsError: String?
    var casesError:     String?

    var lastRefreshed: Date?

    private let api = SophosAPIService.shared

    // MARK: - Computed

    var isLoading: Bool {
        isLoadingHealth || isLoadingAlerts || isLoadingEndpoints || isLoadingCases
    }

    var criticalAlertCount: Int {
        alerts.filter { $0.severity.lowercased() == "high" }.count
    }

    var healthyEndpointCount: Int {
        endpoints.filter { $0.health?.overall.lowercased() == "good" }.count
    }

    var unhealthyEndpointCount: Int {
        endpoints.filter {
            let s = $0.health?.overall.lowercased() ?? ""
            return s == "bad" || s == "suspicious"
        }.count
    }

    var openHighCases: [SophosCase] {
        cases.filter {
            $0.severity.lowercased() == "high" &&
            $0.status.lowercased() != "closed"
        }
    }

    // MARK: - Refresh all

    func refreshAll(modelContext: ModelContext) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshHealth(modelContext: modelContext) }
            group.addTask { await self.refreshAlerts(modelContext: modelContext) }
            group.addTask { await self.refreshEndpoints(modelContext: modelContext) }
            group.addTask { await self.refreshCases(modelContext: modelContext) }
        }
        lastRefreshed = Date()
    }

    // MARK: - Individual refreshes

    func refreshHealth(modelContext: ModelContext) async {
        isLoadingHealth = true
        healthError = nil
        defer { isLoadingHealth = false }
        do {
            let response = try await api.fetchAccountHealth()
            accountHealth = response
            await persistHealth(response, context: modelContext)
        } catch {
            healthError = error.localizedDescription
            await loadCachedHealth(context: modelContext)
        }
    }

    func refreshAlerts(modelContext: ModelContext) async {
        isLoadingAlerts = true
        alertsError = nil
        defer { isLoadingAlerts = false }
        do {
            let response = try await api.fetchAlerts()
            alerts = response.items
            await persistAlerts(response.items, context: modelContext)
        } catch {
            alertsError = error.localizedDescription
            await loadCachedAlerts(context: modelContext)
        }
    }

    func refreshEndpoints(modelContext: ModelContext) async {
        isLoadingEndpoints = true
        endpointsError = nil
        defer { isLoadingEndpoints = false }
        do {
            let response = try await api.fetchEndpoints()
            endpoints = response.items
            await persistEndpoints(response.items, context: modelContext)
        } catch {
            endpointsError = error.localizedDescription
            await loadCachedEndpoints(context: modelContext)
        }
    }

    func refreshCases(modelContext: ModelContext) async {
        isLoadingCases = true
        casesError = nil
        defer { isLoadingCases = false }
        do {
            let response = try await api.fetchCases(severity: nil)
            cases = response.items
            await persistCases(response.items, context: modelContext)
        } catch {
            casesError = error.localizedDescription
            await loadCachedCases(context: modelContext)
        }
    }

    // MARK: - Persistence

    @MainActor
    private func persistHealth(_ response: AccountHealthResponse, context: ModelContext) {
        let descriptor = FetchDescriptor<CachedAccountHealth>()
        let existing = (try? context.fetch(descriptor))?.first

        let score = response.overall.score ?? 0
        if let existing {
            existing.overallStatus = response.overall.status
            existing.overallScore = score
            existing.endpointStatus = response.endpoint?.status
            existing.serverStatus = response.server?.status
            existing.firewallStatus = response.firewall?.status
            existing.emailStatus = response.email?.status
            existing.lastUpdated = Date()
        } else {
            let cached = CachedAccountHealth(
                overallStatus: response.overall.status,
                overallScore: score,
                endpointStatus: response.endpoint?.status,
                serverStatus: response.server?.status,
                firewallStatus: response.firewall?.status,
                emailStatus: response.email?.status
            )
            context.insert(cached)
        }
        try? context.save()
    }

    @MainActor
    private func persistAlerts(_ items: [SophosAlert], context: ModelContext) {
        // Keep last 7 days — delete older cached alerts
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let deleteDescriptor = FetchDescriptor<CachedAlert>(
            predicate: #Predicate { $0.raisedAt != nil && $0.raisedAt! < cutoff }
        )
        if let old = try? context.fetch(deleteDescriptor) {
            old.forEach { context.delete($0) }
        }

        for alert in items {
            let id = alert.id
            let descriptor = FetchDescriptor<CachedAlert>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = (try? context.fetch(descriptor))?.first {
                existing.severity = alert.severity
                existing.lastUpdated = Date()
            } else {
                context.insert(CachedAlert(from: alert))
            }
        }
        try? context.save()
    }

    @MainActor
    private func persistEndpoints(_ items: [SophosEndpoint], context: ModelContext) {
        for endpoint in items {
            let id = endpoint.id
            let descriptor = FetchDescriptor<CachedEndpoint>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = (try? context.fetch(descriptor))?.first {
                existing.healthOverall = endpoint.health?.overall
                existing.healthThreats = endpoint.health?.threats?.status
                existing.lastSeenAt = endpoint.lastSeenDate
                existing.lastUpdated = Date()
            } else {
                context.insert(CachedEndpoint(from: endpoint))
            }
        }
        try? context.save()
    }

    @MainActor
    private func persistCases(_ items: [SophosCase], context: ModelContext) {
        for c in items {
            let id = c.id
            let descriptor = FetchDescriptor<CachedCase>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = (try? context.fetch(descriptor))?.first {
                existing.status = c.status
                existing.updatedAt = c.updatedDate
                existing.lastUpdated = Date()
            } else {
                context.insert(CachedCase(from: c))
            }
        }
        try? context.save()
    }

    // MARK: - Load from cache

    @MainActor
    private func loadCachedHealth(context: ModelContext) {
        let descriptor = FetchDescriptor<CachedAccountHealth>()
        if let cached = (try? context.fetch(descriptor))?.first {
            accountHealth = AccountHealthResponse(
                overall: .init(score: cached.overallScore, status: cached.overallStatus, checks: nil),
                endpoint: cached.endpointStatus.map { .init(score: nil, status: $0, checks: nil) },
                server: cached.serverStatus.map { .init(score: nil, status: $0, checks: nil) },
                firewall: cached.firewallStatus.map { .init(score: nil, status: $0, checks: nil) },
                email: cached.emailStatus.map { .init(score: nil, status: $0, checks: nil) }
            )
        }
    }

    @MainActor
    private func loadCachedAlerts(context: ModelContext) {
        let descriptor = FetchDescriptor<CachedAlert>(
            sortBy: [SortDescriptor(\.raisedAt, order: .reverse)]
        )
        if let cached = try? context.fetch(descriptor) {
            alerts = cached.map { c in
                SophosAlert(
                    id: c.id,
                    description: c.alertDescription,
                    type: c.type,
                    groupKey: nil,
                    severity: c.severity,
                    category: c.category,
                    product: c.product,
                    tenant: nil,
                    managedAgent: c.agentId.map { SophosAlert.ManagedAgentRef(id: $0, type: c.agentType) },
                    person: c.personName.map { SophosAlert.PersonRef(id: nil, name: $0) },
                    raisedAt: c.raisedAt.map { ISO8601DateFormatter().string(from: $0) },
                    allowedActions: c.allowedActions
                )
            }
        }
    }

    @MainActor
    private func loadCachedEndpoints(context: ModelContext) {
        let descriptor = FetchDescriptor<CachedEndpoint>(
            sortBy: [SortDescriptor(\.hostname)]
        )
        if let cached = try? context.fetch(descriptor) {
            endpoints = cached.map { c in
                SophosEndpoint(
                    id: c.id,
                    type: c.type,
                    tenant: nil,
                    hostname: c.hostname,
                    health: c.healthOverall.map {
                        SophosEndpoint.EndpointHealth(
                            overall: $0,
                            threats: c.healthThreats.map { SophosEndpoint.EndpointHealth.ThreatHealth(status: $0) },
                            services: c.healthServices.map { SophosEndpoint.EndpointHealth.ServiceHealth(status: $0, serviceDetails: nil) }
                        )
                    },
                    os: SophosEndpoint.OperatingSystem(
                        isServer: c.osIsServer,
                        platform: c.osPlatform,
                        name: c.osName,
                        majorVersion: c.osMajorVersion,
                        minorVersion: nil,
                        build: nil
                    ),
                    ipv4Addresses: c.ipv4Addresses,
                    ipv6Addresses: nil,
                    macAddresses: nil,
                    associatedPerson: c.associatedPersonName.map {
                        SophosEndpoint.AssociatedPerson(id: nil, name: $0, viaLogin: c.associatedPersonLogin)
                    },
                    assignedProducts: nil,
                    lastSeenAt: c.lastSeenAt.map { ISO8601DateFormatter().string(from: $0) },
                    tamperProtectionEnabled: c.tamperProtectionEnabled
                )
            }
        }
    }

    @MainActor
    private func loadCachedCases(context: ModelContext) {
        let descriptor = FetchDescriptor<CachedCase>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let cached = try? context.fetch(descriptor) {
            cases = cached.map { c in
                SophosCase(
                    id: c.id,
                    tenant: nil,
                    assignee: c.assigneeName.map { SophosCase.Assignee(id: nil, name: $0) },
                    type: c.type,
                    name: c.name,
                    severity: c.severity,
                    status: c.status,
                    managedBy: c.managedBy,
                    overview: c.overview,
                    detectionCount: c.detectionCount,
                    createdAt: c.createdAt.map { ISO8601DateFormatter().string(from: $0) },
                    updatedAt: c.updatedAt.map { ISO8601DateFormatter().string(from: $0) }
                )
            }
        }
    }
}
