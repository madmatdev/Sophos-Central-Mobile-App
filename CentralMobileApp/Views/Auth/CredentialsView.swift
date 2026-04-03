import SwiftUI

struct CredentialsView: View {

    @Bindable var viewModel: AuthViewModel
    @State private var showSecret = false
    @State private var idPasteFlash = false
    @State private var secretPasteFlash = false

    // UUID format: 8-4-4-4-12 hex chars
    private var clientIdValid: Bool {
        let clean = viewModel.clientId.trimmingCharacters(in: .whitespaces)
        return clean.count == 36 &&
            clean.range(of: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#, options: .regularExpression) != nil
    }

    // Sophos secrets are 96-char hex strings
    private var clientSecretValid: Bool {
        let clean = viewModel.clientSecret.trimmingCharacters(in: .whitespaces)
        return clean.count >= 32 &&
            clean.range(of: #"^[0-9a-fA-F]+$"#, options: .regularExpression) != nil
    }

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // MARK: - Header
                    VStack(spacing: SophosTheme.Spacing.lg) {
                        Spacer().frame(height: 60)
                        SophosLogoView(height: 44, showWordmark: true)
                        VStack(spacing: SophosTheme.Spacing.xs) {
                            Text("Central Mobile")
                                .font(SophosTheme.Typography.title2(.semibold))
                                .foregroundColor(SophosTheme.Colors.textPrimary)
                            Text("Sign in with your Sophos Central API credentials")
                                .font(SophosTheme.Typography.subheadline())
                                .foregroundColor(SophosTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, SophosTheme.Spacing.xl)

                    // MARK: - Form
                    VStack(spacing: SophosTheme.Spacing.md) {
                        Spacer().frame(height: SophosTheme.Spacing.xxl)

                        // Client ID field
                        ApiKeyField(
                            label: "Client ID",
                            hint: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
                            text: $viewModel.clientId,
                            isValid: clientIdValid,
                            isMultiline: false,
                            pasteFlash: $idPasteFlash,
                            onPaste: {
                                if let s = UIPasteboard.general.string {
                                    viewModel.clientId = s.trimmingCharacters(in: .whitespacesAndNewlines)
                                    idPasteFlash = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { idPasteFlash = false }
                                }
                            }
                        )

                        // Client Secret field
                        ApiKeyField(
                            label: "Client Secret",
                            hint: "96-character hex string",
                            text: $viewModel.clientSecret,
                            isValid: clientSecretValid,
                            isMultiline: true,
                            showToggle: true,
                            showSecret: $showSecret,
                            pasteFlash: $secretPasteFlash,
                            onPaste: {
                                if let s = UIPasteboard.general.string {
                                    viewModel.clientSecret = s.trimmingCharacters(in: .whitespacesAndNewlines)
                                    secretPasteFlash = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { secretPasteFlash = false }
                                }
                            }
                        )

                        // Info note
                        HStack(alignment: .top, spacing: SophosTheme.Spacing.xs) {
                            Image(systemName: "info.circle")
                                .foregroundColor(SophosTheme.Colors.sophosBlue)
                                .font(.system(size: 14))
                                .padding(.top, 1)
                            Text("Generate credentials in Sophos Central Admin → Global Settings → API Credentials. Requires Super Admin role.")
                                .font(SophosTheme.Typography.caption())
                                .foregroundColor(SophosTheme.Colors.textSecondary)
                        }
                        .padding(SophosTheme.Spacing.sm)
                        .background(SophosTheme.Colors.backgroundCard2)
                        .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))

                        // Error message
                        if let error = viewModel.errorMessage {
                            HStack(spacing: SophosTheme.Spacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(SophosTheme.Colors.statusCritical)
                                Text(error)
                                    .font(SophosTheme.Typography.footnote())
                                    .foregroundColor(SophosTheme.Colors.statusCritical)
                            }
                            .padding(SophosTheme.Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(SophosTheme.Colors.statusCritical.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
                        }

                        // Sign In button
                        Button {
                            // Auto-trim before submitting
                            viewModel.clientId = viewModel.clientId.trimmingCharacters(in: .whitespacesAndNewlines)
                            viewModel.clientSecret = viewModel.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
                            Task { await viewModel.signIn() }
                        } label: {
                            ZStack {
                                if viewModel.isAuthenticating {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Sign In")
                                        .font(SophosTheme.Typography.headline())
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                viewModel.isAuthenticating
                                    ? SophosTheme.Colors.sophosBlue.opacity(0.6)
                                    : SophosTheme.Colors.sophosBlue
                            )
                            .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
                        }
                        .disabled(viewModel.isAuthenticating)
                    }
                    .padding(.horizontal, SophosTheme.Spacing.lg)

                    // Demo Mode button
                    Button {
                        DemoDataService.isDemoMode = true
                        viewModel.isAuthenticated = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.rectangle")
                            Text("Enter Demo Mode")
                                .font(SophosTheme.Typography.subheadline(.semibold))
                        }
                        .foregroundStyle(SophosTheme.Colors.sophosBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .padding(.horizontal, SophosTheme.Spacing.lg)

                    Spacer().frame(height: SophosTheme.Spacing.xxl)
                }
            }
        }
    }

}

// MARK: - ApiKeyField

private struct ApiKeyField: View {
    let label: String
    let hint: String
    @Binding var text: String
    let isValid: Bool
    var isMultiline: Bool = false
    var showToggle: Bool = false
    @Binding var showSecret: Bool
    @Binding var pasteFlash: Bool
    let onPaste: () -> Void

    init(label: String, hint: String, text: Binding<String>, isValid: Bool,
         isMultiline: Bool = false, showToggle: Bool = false,
         showSecret: Binding<Bool> = .constant(false),
         pasteFlash: Binding<Bool>, onPaste: @escaping () -> Void) {
        self.label = label
        self.hint = hint
        self._text = text
        self.isValid = isValid
        self.isMultiline = isMultiline
        self.showToggle = showToggle
        self._showSecret = showSecret
        self._pasteFlash = pasteFlash
        self.onPaste = onPaste
    }

    private var borderColor: Color {
        if text.isEmpty { return SophosTheme.Colors.inputBorder }
        return isValid ? SophosTheme.Colors.statusHealthy : SophosTheme.Colors.inputBorder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SophosTheme.Spacing.xs) {

            // Label row
            HStack {
                Text(label)
                    .sophosSectionHeader()
                    .padding(.leading, SophosTheme.Spacing.xs)
                Spacer()
                // Validation badge
                if !text.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .font(.system(size: 12))
                        Text(isValid ? "Valid" : "Check format")
                            .font(SophosTheme.Typography.caption())
                    }
                    .foregroundColor(isValid ? SophosTheme.Colors.statusHealthy : SophosTheme.Colors.textSecondary)
                }
            }

            // Input box
            VStack(spacing: 0) {
                if isMultiline {
                    multilineInput
                } else {
                    singleLineInput
                }

                Divider()
                    .background(SophosTheme.Colors.divider)

                // Toolbar row
                HStack(spacing: SophosTheme.Spacing.sm) {
                    Text(hint)
                        .font(SophosTheme.Typography.caption())
                        .foregroundColor(SophosTheme.Colors.textTertiary)
                        .lineLimit(1)

                    Spacer()

                    if !text.isEmpty {
                        Button {
                            text = ""
                        } label: {
                            Label("Clear", systemImage: "xmark.circle.fill")
                                .font(SophosTheme.Typography.caption())
                                .foregroundColor(SophosTheme.Colors.textSecondary)
                                .labelStyle(.titleAndIcon)
                        }
                    }

                    Button(action: onPaste) {
                        Label(pasteFlash ? "Pasted!" : "Paste", systemImage: pasteFlash ? "checkmark" : "doc.on.clipboard")
                            .font(SophosTheme.Typography.caption(.semibold))
                            .foregroundColor(pasteFlash ? SophosTheme.Colors.statusHealthy : SophosTheme.Colors.sophosBlue)
                            .labelStyle(.titleAndIcon)
                    }
                    .animation(.easeInOut(duration: 0.2), value: pasteFlash)
                }
                .padding(.horizontal, SophosTheme.Spacing.sm)
                .padding(.vertical, 8)
                .background(SophosTheme.Colors.backgroundCard2)
            }
            .background(SophosTheme.Colors.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: SophosTheme.Radius.sm)
                    .stroke(borderColor, lineWidth: borderColor == SophosTheme.Colors.statusHealthy ? 1.5 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isValid)
        }
    }

    @ViewBuilder
    private var singleLineInput: some View {
        TextField("", text: $text, prompt:
            Text("Tap Paste or type here").foregroundColor(SophosTheme.Colors.textTertiary)
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .keyboardType(.asciiCapable)
        .font(.system(.body, design: .monospaced))
        .foregroundColor(SophosTheme.Colors.textPrimary)
        .padding(SophosTheme.Spacing.md)
        .onChange(of: text) { _, new in
            // Auto-strip newlines typed/pasted into single line
            if new.contains("\n") {
                text = new.replacingOccurrences(of: "\n", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
    }

    @ViewBuilder
    private var multilineInput: some View {
        HStack(alignment: .top) {
            Group {
                if showSecret {
                    TextField("", text: $text, prompt:
                        Text("Tap Paste or type here").foregroundColor(SophosTheme.Colors.textTertiary),
                        axis: .vertical
                    )
                    .lineLimit(3...5)
                } else {
                    SecureField("", text: $text, prompt:
                        Text("Tap Paste or type here").foregroundColor(SophosTheme.Colors.textTertiary)
                    )
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(SophosTheme.Colors.textPrimary)

            if showToggle {
                Button {
                    showSecret.toggle()
                } label: {
                    Image(systemName: showSecret ? "eye.slash" : "eye")
                        .foregroundColor(SophosTheme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .padding(.top, 2)
            }
        }
        .padding(SophosTheme.Spacing.md)
    }
}
