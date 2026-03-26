import SwiftUI
import SwiftData

struct NotificationSettingsView: View {

    @Query private var preferences: [NotificationPreference]
    @Environment(\.modelContext) private var modelContext

    @State private var permissionGranted: Bool = false
    @State private var highEnabled:    Bool = true
    @State private var mediumEnabled:  Bool = true
    @State private var lowEnabled:     Bool = false
    @State private var endpointEnabled: Bool = true
    @State private var emailEnabled:    Bool = true
    @State private var firewallEnabled: Bool = true
    @State private var quietHoursEnabled: Bool = false
    @State private var quietStart: Int = 22
    @State private var quietEnd:   Int = 7

    private var pref: NotificationPreference? { preferences.first }

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            List {

                // MARK: - Permission status
                Section {
                    HStack(spacing: SophosTheme.Spacing.sm) {
                        Image(systemName: permissionGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(permissionGranted ? SophosTheme.Colors.statusHealthy : SophosTheme.Colors.statusWarning)
                        Text(permissionGranted ? "Push notifications enabled" : "Push notifications not enabled")
                            .font(SophosTheme.Typography.body())
                            .foregroundColor(SophosTheme.Colors.textPrimary)
                        Spacer()
                        if !permissionGranted {
                            Button("Enable") {
                                Task {
                                    permissionGranted = await PushNotificationService.shared.requestPermission()
                                }
                            }
                            .font(SophosTheme.Typography.footnote(.semibold))
                            .foregroundColor(SophosTheme.Colors.sophosBlue)
                        }
                    }
                }
                .listRowBackground(SophosTheme.Colors.backgroundCard)

                // MARK: - Severity filters
                Section {
                    SeverityToggleRow(label: "Critical (High)",  color: SophosTheme.Colors.severityHigh,    isOn: $highEnabled)
                    SeverityToggleRow(label: "Warning (Medium)", color: SophosTheme.Colors.severityMedium,  isOn: $mediumEnabled)
                    SeverityToggleRow(label: "Low",              color: SophosTheme.Colors.severityLow,     isOn: $lowEnabled)
                } header: {
                    Text("Alert Severity").sophosSectionHeader()
                } footer: {
                    Text("Only receive push notifications for the selected severity levels.")
                        .font(SophosTheme.Typography.caption())
                        .foregroundColor(SophosTheme.Colors.textTertiary)
                }
                .listRowBackground(SophosTheme.Colors.backgroundCard)

                // MARK: - Product filters
                Section {
                    ProductToggleRow(icon: "laptopcomputer", label: "Endpoint Alerts",  isOn: $endpointEnabled)
                    ProductToggleRow(icon: "envelope.badge",  label: "Email Alerts",     isOn: $emailEnabled)
                    ProductToggleRow(icon: "shield.lefthalf.filled", label: "Firewall Alerts", isOn: $firewallEnabled)
                } header: {
                    Text("Product Filters").sophosSectionHeader()
                }
                .listRowBackground(SophosTheme.Colors.backgroundCard)

                // MARK: - Quiet hours
                Section {
                    Toggle(isOn: $quietHoursEnabled) {
                        SettingsRow(icon: "moon.fill", label: "Quiet Hours", color: SophosTheme.Colors.sophosBlue)
                    }
                    .tint(SophosTheme.Colors.sophosBlue)

                    if quietHoursEnabled {
                        HStack {
                            Text("Start")
                                .font(SophosTheme.Typography.body())
                                .foregroundColor(SophosTheme.Colors.textPrimary)
                            Spacer()
                            Picker("Start", selection: $quietStart) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(hourLabel(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(SophosTheme.Colors.sophosBlue)
                        }

                        HStack {
                            Text("End")
                                .font(SophosTheme.Typography.body())
                                .foregroundColor(SophosTheme.Colors.textPrimary)
                            Spacer()
                            Picker("End", selection: $quietEnd) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(hourLabel(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(SophosTheme.Colors.sophosBlue)
                        }
                    }
                } header: {
                    Text("Do Not Disturb").sophosSectionHeader()
                } footer: {
                    if quietHoursEnabled {
                        Text("No notifications will be sent between \(hourLabel(quietStart)) and \(hourLabel(quietEnd)).")
                            .font(SophosTheme.Typography.caption())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                    }
                }
                .listRowBackground(SophosTheme.Colors.backgroundCard)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(SophosTheme.Colors.backgroundPrimary)
        }
        .navigationTitle("Push Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: highEnabled)       { save() }
        .onChange(of: mediumEnabled)     { save() }
        .onChange(of: lowEnabled)        { save() }
        .onChange(of: endpointEnabled)   { save() }
        .onChange(of: emailEnabled)      { save() }
        .onChange(of: firewallEnabled)   { save() }
        .onChange(of: quietHoursEnabled) { save() }
        .onChange(of: quietStart)        { save() }
        .onChange(of: quietEnd)          { save() }
        .task {
            await checkPermission()
            loadPreferences()
        }
    }

    // MARK: - Helpers

    private func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
    }

    private func loadPreferences() {
        if preferences.isEmpty {
            let newPref = NotificationPreference()
            modelContext.insert(newPref)
            try? modelContext.save()
        }
        guard let p = pref else { return }
        highEnabled    = p.severityList.contains("high")
        mediumEnabled  = p.severityList.contains("medium")
        lowEnabled     = p.severityList.contains("low")
        endpointEnabled = p.endpointAlertsEnabled
        emailEnabled    = p.emailAlertsEnabled
        firewallEnabled = p.firewallAlertsEnabled
        quietHoursEnabled = p.quietHoursEnabled
        quietStart = p.quietHoursStart
        quietEnd   = p.quietHoursEnd
    }

    private func save() {
        let p: NotificationPreference
        if let existing = pref {
            p = existing
        } else {
            p = NotificationPreference()
            modelContext.insert(p)
        }

        var severities: [String] = []
        if highEnabled   { severities.append("high") }
        if mediumEnabled { severities.append("medium") }
        if lowEnabled    { severities.append("low") }
        p.severityList = severities

        p.endpointAlertsEnabled = endpointEnabled
        p.emailAlertsEnabled    = emailEnabled
        p.firewallAlertsEnabled = firewallEnabled
        p.quietHoursEnabled     = quietHoursEnabled
        p.quietHoursStart       = quietStart
        p.quietHoursEnd         = quietEnd

        try? modelContext.save()
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        return "\(h):00 \(period)"
    }
}

// MARK: - Toggle rows

struct SeverityToggleRow: View {
    let label: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: SophosTheme.Spacing.sm) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(label)
                    .font(SophosTheme.Typography.body())
                    .foregroundColor(SophosTheme.Colors.textPrimary)
            }
        }
        .tint(SophosTheme.Colors.sophosBlue)
    }
}

struct ProductToggleRow: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsRow(icon: icon, label: label, color: SophosTheme.Colors.sophosBlue)
        }
        .tint(SophosTheme.Colors.sophosBlue)
    }
}

// Needed for NotificationSettingsView to access UNUserNotificationCenter
import UserNotifications
