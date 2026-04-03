import SwiftUI

/// Look up IOCs (hashes, IPs, domains) against VirusTotal and AbuseIPDB.
struct ThreatIntelView: View {
    @State private var ioc = ""
    @State private var iocType: IOCType = .auto
    @State private var loading = false
    @State private var vtResult: ThreatIntelService.VTResult?
    @State private var abuseResult: ThreatIntelService.AbuseIPDBResult?
    @State private var error: String?

    private let intel = ThreatIntelService.shared
    private let keychain = KeychainService.shared

    enum IOCType: String, CaseIterable {
        case auto = "Auto-detect"
        case hash = "File Hash"
        case ip = "IP Address"
        case domain = "Domain"
    }

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: SophosTheme.Spacing.md) {
                    // Input
                    VStack(spacing: SophosTheme.Spacing.sm) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(SophosTheme.Colors.textTertiary)
                            TextField("Hash, IP address, or domain...", text: $ioc)
                                .font(SophosTheme.Typography.body())
                                .foregroundStyle(SophosTheme.Colors.textPrimary)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(SophosTheme.Spacing.sm)
                        .background(SophosTheme.Colors.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))

                        Button {
                            Task { await lookup() }
                        } label: {
                            HStack {
                                if loading {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "shield.checkered")
                                    Text("Lookup")
                                        .font(SophosTheme.Typography.subheadline(.semibold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(ioc.isEmpty ? SophosTheme.Colors.sophosBlue.opacity(0.5) : SophosTheme.Colors.sophosBlue)
                            .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
                        }
                        .disabled(ioc.isEmpty || loading)
                    }
                    .padding(.horizontal, SophosTheme.Spacing.md)
                    .padding(.top, SophosTheme.Spacing.md)

                    if let error {
                        Text(error)
                            .font(SophosTheme.Typography.footnote())
                            .foregroundStyle(SophosTheme.Colors.statusCritical)
                            .padding(.horizontal, SophosTheme.Spacing.md)
                    }

                    // VirusTotal Results
                    if let vt = vtResult {
                        vtCard(vt)
                    }

                    // AbuseIPDB Results
                    if let abuse = abuseResult {
                        abuseCard(abuse)
                    }
                }
            }
        }
        .navigationTitle("Threat Intel")
    }

    // MARK: - VirusTotal Card

    private func vtCard(_ vt: ThreatIntelService.VTResult) -> some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.sm) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(SophosTheme.Colors.sophosBlue)
                Text("VirusTotal")
                    .font(SophosTheme.Typography.headline())
                    .foregroundStyle(SophosTheme.Colors.textPrimary)
                Spacer()
                if let link = vt.permalink, let url = URL(string: link) {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(SophosTheme.Colors.sophosBlue)
                    }
                }
            }

            // Score
            HStack(spacing: SophosTheme.Spacing.md) {
                VStack {
                    Text("\(vt.positives)/\(vt.total)")
                        .font(SophosTheme.Typography.title(.semibold))
                        .foregroundStyle(vt.positives > 5 ? SophosTheme.Colors.statusCritical :
                            vt.positives > 0 ? SophosTheme.Colors.statusWarning :
                            SophosTheme.Colors.statusHealthy)
                    Text("Detections")
                        .font(SophosTheme.Typography.caption2())
                        .foregroundStyle(SophosTheme.Colors.textSecondary)
                }

                Spacer()

                Text(vt.positives > 5 ? "🔴 Malicious" :
                     vt.positives > 0 ? "🟠 Suspicious" : "🟢 Clean")
                    .font(SophosTheme.Typography.subheadline(.semibold))
                    .foregroundStyle(SophosTheme.Colors.textPrimary)
            }

            // Top detections
            if !vt.detections.isEmpty {
                Divider().background(SophosTheme.Colors.divider)
                ForEach(vt.detections.prefix(5), id: \.self) { det in
                    Text(det)
                        .font(SophosTheme.Typography.caption2())
                        .foregroundStyle(SophosTheme.Colors.textSecondary)
                }
            }
        }
        .padding(SophosTheme.Spacing.md)
        .background(SophosTheme.Colors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.md))
        .padding(.horizontal, SophosTheme.Spacing.md)
    }

    // MARK: - AbuseIPDB Card

    private func abuseCard(_ abuse: ThreatIntelService.AbuseIPDBResult) -> some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.shield")
                    .foregroundStyle(.orange)
                Text("AbuseIPDB")
                    .font(SophosTheme.Typography.headline())
                    .foregroundStyle(SophosTheme.Colors.textPrimary)
            }

            HStack(spacing: SophosTheme.Spacing.md) {
                VStack {
                    Text("\(abuse.abuseScore)%")
                        .font(SophosTheme.Typography.title(.semibold))
                        .foregroundStyle(abuse.abuseScore > 50 ? SophosTheme.Colors.statusCritical :
                            abuse.abuseScore > 10 ? SophosTheme.Colors.statusWarning :
                            SophosTheme.Colors.statusHealthy)
                    Text("Abuse Score")
                        .font(SophosTheme.Typography.caption2())
                        .foregroundStyle(SophosTheme.Colors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(abuse.totalReports) reports")
                        .font(SophosTheme.Typography.subheadline())
                        .foregroundStyle(SophosTheme.Colors.textPrimary)
                    if let country = abuse.country {
                        Text(country)
                            .font(SophosTheme.Typography.caption2())
                            .foregroundStyle(SophosTheme.Colors.textSecondary)
                    }
                }
            }

            if let isp = abuse.isp {
                HStack {
                    Text("ISP:").foregroundStyle(SophosTheme.Colors.textTertiary)
                    Text(isp).foregroundStyle(SophosTheme.Colors.textSecondary)
                }
                .font(SophosTheme.Typography.caption2())
            }
        }
        .padding(SophosTheme.Spacing.md)
        .background(SophosTheme.Colors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.md))
        .padding(.horizontal, SophosTheme.Spacing.md)
    }

    // MARK: - Lookup

    private func lookup() async {
        loading = true
        error = nil
        vtResult = nil
        abuseResult = nil

        let trimmed = ioc.trimmingCharacters(in: .whitespacesAndNewlines)
        let detected = detectIOCType(trimmed)
        let vtKey = keychain.read(.virusTotalAPIKey) ?? ""
        let abuseKey = keychain.read(.abuseIPDBAPIKey) ?? ""

        do {
            switch detected {
            case .hash:
                if !vtKey.isEmpty {
                    vtResult = try await intel.lookupHash(trimmed, apiKey: vtKey)
                } else {
                    error = "VirusTotal API key not configured. Go to Settings → AI Configuration."
                }
            case .ip:
                async let vt: Void = {
                    if !vtKey.isEmpty { self.vtResult = try? await self.intel.lookupIP(trimmed, apiKey: vtKey) }
                }()
                async let abuse: Void = {
                    if !abuseKey.isEmpty { self.abuseResult = try? await self.intel.lookupAbuseIPDB(trimmed, apiKey: abuseKey) }
                }()
                _ = await (vt, abuse)
                if vtResult == nil && abuseResult == nil {
                    error = "No API keys configured for IP lookup."
                }
            case .domain:
                if !vtKey.isEmpty {
                    vtResult = try await intel.lookupDomain(trimmed, apiKey: vtKey)
                } else {
                    error = "VirusTotal API key not configured."
                }
            default:
                error = "Could not identify IOC type. Enter a hash, IP, or domain."
            }
        } catch {
            self.error = error.localizedDescription
        }

        loading = false
    }

    private func detectIOCType(_ value: String) -> IOCType {
        // SHA256/SHA1/MD5
        if value.range(of: "^[a-fA-F0-9]{32,64}$", options: .regularExpression) != nil { return .hash }
        // IPv4
        if value.range(of: "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", options: .regularExpression) != nil { return .ip }
        // Domain
        if value.contains(".") && !value.contains(" ") { return .domain }
        return .auto
    }
}
