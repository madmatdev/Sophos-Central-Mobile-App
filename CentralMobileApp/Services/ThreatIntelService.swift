import Foundation

/// Enriches IOCs (hashes, IPs, domains) with external threat intelligence.
actor ThreatIntelService {

    static let shared = ThreatIntelService()
    private init() {}

    // MARK: - VirusTotal

    struct VTResult: Codable {
        let positives: Int
        let total: Int
        let scanDate: String?
        let permalink: String?
        let detections: [String]
    }

    func lookupHash(_ hash: String, apiKey: String) async throws -> VTResult {
        let url = "https://www.virustotal.com/api/v3/files/\(hash)"
        var request = URLRequest(url: URL(string: url)!)
        request.setValue(apiKey, forHTTPHeaderField: "x-apikey")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ThreatIntelError.lookupFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let attrs = (json?["data"] as? [String: Any])?["attributes"] as? [String: Any]
        let stats = attrs?["last_analysis_stats"] as? [String: Int]
        let results = attrs?["last_analysis_results"] as? [String: [String: Any]]

        let positives = (stats?["malicious"] ?? 0) + (stats?["suspicious"] ?? 0)
        let total = (stats?["malicious"] ?? 0) + (stats?["undetected"] ?? 0) + (stats?["suspicious"] ?? 0) + (stats?["harmless"] ?? 0)

        let detections = results?.compactMap { (engine, result) -> String? in
            let category = result["category"] as? String
            let name = result["result"] as? String
            guard category == "malicious" || category == "suspicious", let name else { return nil }
            return "\(engine): \(name)"
        } ?? []

        return VTResult(
            positives: positives,
            total: total,
            scanDate: attrs?["last_analysis_date"] as? String,
            permalink: "https://www.virustotal.com/gui/file/\(hash)",
            detections: Array(detections.prefix(10))
        )
    }

    func lookupIP(_ ip: String, apiKey: String) async throws -> VTResult {
        let url = "https://www.virustotal.com/api/v3/ip_addresses/\(ip)"
        var request = URLRequest(url: URL(string: url)!)
        request.setValue(apiKey, forHTTPHeaderField: "x-apikey")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ThreatIntelError.lookupFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let attrs = (json?["data"] as? [String: Any])?["attributes"] as? [String: Any]
        let stats = attrs?["last_analysis_stats"] as? [String: Int]

        let positives = (stats?["malicious"] ?? 0) + (stats?["suspicious"] ?? 0)
        let total = (stats?["malicious"] ?? 0) + (stats?["undetected"] ?? 0) + (stats?["harmless"] ?? 0)

        return VTResult(
            positives: positives, total: total,
            scanDate: nil,
            permalink: "https://www.virustotal.com/gui/ip-address/\(ip)",
            detections: []
        )
    }

    func lookupDomain(_ domain: String, apiKey: String) async throws -> VTResult {
        let url = "https://www.virustotal.com/api/v3/domains/\(domain)"
        var request = URLRequest(url: URL(string: url)!)
        request.setValue(apiKey, forHTTPHeaderField: "x-apikey")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ThreatIntelError.lookupFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let attrs = (json?["data"] as? [String: Any])?["attributes"] as? [String: Any]
        let stats = attrs?["last_analysis_stats"] as? [String: Int]

        let positives = (stats?["malicious"] ?? 0) + (stats?["suspicious"] ?? 0)
        let total = (stats?["malicious"] ?? 0) + (stats?["undetected"] ?? 0) + (stats?["harmless"] ?? 0)

        return VTResult(
            positives: positives, total: total,
            scanDate: nil,
            permalink: "https://www.virustotal.com/gui/domain/\(domain)",
            detections: []
        )
    }

    // MARK: - AbuseIPDB

    struct AbuseIPDBResult: Codable {
        let abuseScore: Int
        let totalReports: Int
        let country: String?
        let isp: String?
        let domain: String?
        let isPublic: Bool
        let lastReported: String?
    }

    func lookupAbuseIPDB(_ ip: String, apiKey: String) async throws -> AbuseIPDBResult {
        let url = "https://api.abuseipdb.com/api/v2/check?ipAddress=\(ip)&maxAgeInDays=90"
        var request = URLRequest(url: URL(string: url)!)
        request.setValue(apiKey, forHTTPHeaderField: "Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ThreatIntelError.lookupFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let d = json?["data"] as? [String: Any]

        return AbuseIPDBResult(
            abuseScore: d?["abuseConfidenceScore"] as? Int ?? 0,
            totalReports: d?["totalReports"] as? Int ?? 0,
            country: d?["countryCode"] as? String,
            isp: d?["isp"] as? String,
            domain: d?["domain"] as? String,
            isPublic: d?["isPublic"] as? Bool ?? false,
            lastReported: d?["lastReportedAt"] as? String
        )
    }
}

enum ThreatIntelError: LocalizedError {
    case lookupFailed
    case invalidIOC

    var errorDescription: String? {
        switch self {
        case .lookupFailed: return "Threat intel lookup failed."
        case .invalidIOC:   return "Invalid indicator of compromise."
        }
    }
}
