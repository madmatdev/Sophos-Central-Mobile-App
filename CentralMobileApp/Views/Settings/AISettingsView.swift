import SwiftUI

/// Settings view for AI Agent and backend configuration.
struct AISettingsView: View {
    @State private var groqKey: String = ""
    @State private var saved = false

    private let keychain = KeychainService.shared

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            List {
                Section {
                    SecureField("Groq API Key", text: $groqKey)
                        .font(SophosTheme.Typography.body())
                        .foregroundStyle(SophosTheme.Colors.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        keychain.save(groqKey, for: .groqAPIKey)
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                    } label: {
                        HStack {
                            Text("Save API Key")
                                .font(SophosTheme.Typography.body(.semibold))
                            if saved {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .disabled(groqKey.isEmpty)
                } header: {
                    Text("Groq AI").sophosSectionHeader()
                } footer: {
                    Text("Powers the AI Assistant. Get your key at console.groq.com")
                        .font(SophosTheme.Typography.caption2())
                        .foregroundStyle(SophosTheme.Colors.textTertiary)
                }
                .listRowBackground(SophosTheme.Colors.backgroundCard)

                Section {
                    SettingsInfoRow(label: "Model", value: "llama-3.3-70b-versatile")
                    SettingsInfoRow(label: "Provider", value: "Groq")
                    SettingsInfoRow(label: "Key Status", value: keychain.read(.groqAPIKey) != nil ? "Configured" : "Not Set")
                } header: {
                    Text("Status").sophosSectionHeader()
                }
                .listRowBackground(SophosTheme.Colors.backgroundCard)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("AI Configuration")
        .onAppear {
            groqKey = keychain.read(.groqAPIKey) ?? ""
        }
    }
}
