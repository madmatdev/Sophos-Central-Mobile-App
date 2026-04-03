import Foundation

/// Provides realistic fake data for demo mode.
/// SEs can demo the app without connecting to a real tenant.
enum DemoDataService {

    // MARK: - Demo Mode Toggle

    private static let demoModeKey = "demo_mode_enabled"

    static var isDemoMode: Bool {
        get { UserDefaults.standard.bool(forKey: demoModeKey) }
        set { UserDefaults.standard.set(newValue, forKey: demoModeKey) }
    }

    // MARK: - Account Health

    static func accountHealth() -> AccountHealthResponse {
        AccountHealthResponse(
            endpoint: EndpointHealth(
                protection: HealthComponent(status: "warning", score: 85),
                policy: HealthComponent(status: "good", score: 95),
                tamperProtection: HealthComponent(status: "warning", score: 80),
                exclusions: HealthComponent(status: "good", score: 100)
            )
        )
    }

    // MARK: - Alerts

    static func alerts() -> [SophosAlert] {
        let now = Date()
        return [
            makeAlert(id: "d1", desc: "Malicious file detected: Troj/Ransom-GKL at C:\\Users\\jsmith\\Downloads\\invoice.exe",
                      severity: "high", category: "malware", product: "endpoint",
                      person: "John Smith", ago: -3600),
            makeAlert(id: "d2", desc: "Suspicious PowerShell execution detected on FINANCE-WS-03",
                      severity: "high", category: "suspicious", product: "endpoint",
                      person: "Sarah Chen", ago: -7200),
            makeAlert(id: "d3", desc: "CryptoGuard detected encryption activity on PACS-IMAGING-1",
                      severity: "high", category: "ransomware", product: "endpoint",
                      person: nil, ago: -1800),
            makeAlert(id: "d4", desc: "Firewall has not contacted Sophos Central for the past 5 minutes",
                      severity: "medium", category: "connectivity", product: "firewall",
                      person: nil, ago: -900),
            makeAlert(id: "d5", desc: "Endpoint not protected: MARKETING-WS-07 has outdated definitions",
                      severity: "medium", category: "protection", product: "endpoint",
                      person: "Mike Torres", ago: -14400),
            makeAlert(id: "d6", desc: "PUA detected: PUA/InstallCore on SALES-WS-02",
                      severity: "low", category: "pua", product: "endpoint",
                      person: "Emily Davis", ago: -86400),
        ]
    }

    private static func makeAlert(id: String, desc: String, severity: String, category: String,
                                   product: String, person: String?, ago: TimeInterval) -> SophosAlert {
        SophosAlert(
            id: id,
            description: desc,
            type: "Event::Endpoint::\(category.capitalized)",
            groupKey: nil,
            severity: severity,
            category: category,
            product: product,
            tenant: nil,
            managedAgent: nil,
            person: person.map { SophosAlert.PersonRef(id: "p-\(id)", name: $0) },
            raisedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(ago)),
            allowedActions: ["acknowledge"]
        )
    }

    // MARK: - Endpoints

    static func endpoints() -> [SophosEndpoint] {
        [
            makeEndpoint(id: "de1", name: "EXEC-WS-01", platform: "windows", osName: "Windows 11 Pro", health: "good", isServer: false, ago: -300),
            makeEndpoint(id: "de2", name: "SALES-WS-02", platform: "windows", osName: "Windows 11 Pro", health: "suspicious", isServer: false, ago: -600),
            makeEndpoint(id: "de3", name: "FINANCE-WS-03", platform: "windows", osName: "Windows 11 Enterprise", health: "bad", isServer: false, ago: -120),
            makeEndpoint(id: "de4", name: "DEV-MAC-04", platform: "macOS", osName: "macOS 15.2", health: "good", isServer: false, ago: -1800),
            makeEndpoint(id: "de5", name: "PACS-IMAGING-1", platform: "windows", osName: "Windows Server 2022", health: "bad", isServer: true, ago: -60),
            makeEndpoint(id: "de6", name: "DC-01", platform: "windows", osName: "Windows Server 2022", health: "good", isServer: true, ago: -180),
            makeEndpoint(id: "de7", name: "MARKETING-WS-07", platform: "windows", osName: "Windows 11 Pro", health: "suspicious", isServer: false, ago: -43200),
            makeEndpoint(id: "de8", name: "HR-WS-08", platform: "windows", osName: "Windows 11 Pro", health: "good", isServer: false, ago: -900),
            makeEndpoint(id: "de9", name: "FILE-SRV-01", platform: "windows", osName: "Windows Server 2022", health: "good", isServer: true, ago: -240),
            makeEndpoint(id: "de10", name: "PRINT-SRV-01", platform: "windows", osName: "Windows Server 2019", health: "good", isServer: true, ago: -7200),
        ]
    }

    private static func makeEndpoint(id: String, name: String, platform: String, osName: String,
                                      health: String, isServer: Bool, ago: TimeInterval) -> SophosEndpoint {
        SophosEndpoint(
            id: id,
            type: isServer ? "server" : "computer",
            tenant: nil,
            hostname: name,
            health: SophosEndpoint.EndpointHealth(
                overall: health,
                threats: nil,
                services: nil
            ),
            os: SophosEndpoint.OperatingSystem(
                isServer: isServer,
                platform: platform,
                name: osName,
                majorVersion: nil, minorVersion: nil, build: nil
            ),
            ipv4Addresses: ["192.168.1.\(Int.random(in: 10...250))"],
            ipv6Addresses: nil,
            macAddresses: nil,
            associatedPerson: nil,
            assignedProducts: nil,
            lastSeenAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(ago)),
            tamperProtectionEnabled: health != "bad",
            online: health != "bad" && ago > -3600
        )
    }

    // MARK: - Cases

    static func cases() -> [SophosCase] {
        [
            SophosCase(
                id: "dc1",
                tenant: nil,
                assignee: SophosCase.Assignee(id: "a1", name: "SOC Team"),
                type: "investigation",
                name: "LockBit 3.0 Ransomware — PACS-IMAGING-1",
                severity: "high",
                status: "inProgress",
                managedBy: "self",
                overview: "CryptoGuard blocked encryption attempt. Shadow copy deletion detected. Investigating lateral movement from FINANCE-WS-03.",
                detectionCount: 4,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)),
                updatedAt: nil
            ),
            SophosCase(
                id: "dc2",
                tenant: nil,
                assignee: nil,
                type: "investigation",
                name: "Suspicious PowerShell Activity — FINANCE-WS-03",
                severity: "high",
                status: "open",
                managedBy: "self",
                overview: "Encoded PowerShell commands detected downloading payload from external C2. MITRE: T1059.001, T1105.",
                detectionCount: 2,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200)),
                updatedAt: nil
            ),
            SophosCase(
                id: "dc3",
                tenant: nil,
                assignee: SophosCase.Assignee(id: "a2", name: "IT Help Desk"),
                type: "investigation",
                name: "PUA Cleanup Required — SALES-WS-02",
                severity: "low",
                status: "inProgress",
                managedBy: "self",
                overview: "Potentially unwanted application InstallCore found. Manual cleanup recommended.",
                detectionCount: 1,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)),
                updatedAt: nil
            ),
        ]
    }
}
