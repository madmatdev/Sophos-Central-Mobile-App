import SwiftUI

struct CredentialsView: View {

    @Bindable var viewModel: AuthViewModel
    @State private var showSecret = false

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
                        VStack(alignment: .leading, spacing: SophosTheme.Spacing.xs) {
                            Text("Client ID")
                                .sophosSectionHeader()
                                .padding(.leading, SophosTheme.Spacing.xs)

                            TextField("", text: $viewModel.clientId, prompt:
                                Text("Enter Client ID").foregroundColor(SophosTheme.Colors.textTertiary)
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .padding(SophosTheme.Spacing.md)
                            .background(SophosTheme.Colors.inputBackground)
                            .foregroundColor(SophosTheme.Colors.textPrimary)
                            .font(SophosTheme.Typography.body())
                            .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: SophosTheme.Radius.sm)
                                    .stroke(SophosTheme.Colors.inputBorder, lineWidth: 1)
                            )
                        }

                        // Client Secret field
                        VStack(alignment: .leading, spacing: SophosTheme.Spacing.xs) {
                            Text("Client Secret")
                                .sophosSectionHeader()
                                .padding(.leading, SophosTheme.Spacing.xs)

                            HStack {
                                if showSecret {
                                    TextField("", text: $viewModel.clientSecret, prompt:
                                        Text("Enter Client Secret").foregroundColor(SophosTheme.Colors.textTertiary)
                                    )
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                } else {
                                    SecureField("", text: $viewModel.clientSecret, prompt:
                                        Text("Enter Client Secret").foregroundColor(SophosTheme.Colors.textTertiary)
                                    )
                                }

                                Button {
                                    showSecret.toggle()
                                } label: {
                                    Image(systemName: showSecret ? "eye.slash" : "eye")
                                        .foregroundColor(SophosTheme.Colors.textSecondary)
                                }
                            }
                            .padding(SophosTheme.Spacing.md)
                            .background(SophosTheme.Colors.inputBackground)
                            .foregroundColor(SophosTheme.Colors.textPrimary)
                            .font(SophosTheme.Typography.body())
                            .clipShape(RoundedRectangle(cornerRadius: SophosTheme.Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: SophosTheme.Radius.sm)
                                    .stroke(SophosTheme.Colors.inputBorder, lineWidth: 1)
                            )
                        }

                        // Info note
                        HStack(spacing: SophosTheme.Spacing.xs) {
                            Image(systemName: "info.circle")
                                .foregroundColor(SophosTheme.Colors.sophosBlue)
                                .font(.system(size: 14))
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
                            Task { await viewModel.signIn() }
                        } label: {
                            ZStack {
                                if viewModel.isAuthenticating {
                                    ProgressView()
                                        .tint(.white)
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

                    Spacer().frame(height: SophosTheme.Spacing.xxl)
                }
            }
        }
    }
}
