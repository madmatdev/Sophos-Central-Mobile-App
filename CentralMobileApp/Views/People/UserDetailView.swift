import SwiftUI

struct UserDetailView: View {

    let user: SophosUser

    @Environment(\.dismiss) private var dismiss

    @State private var groups: [UserGroupMembership] = []
    @State private var groupsLoading = false
    @State private var groupsError: String?
    @State private var groupsLoaded = false

    private let api = SophosAPIService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SophosTheme.Spacing.md) {

                        // Profile header
                        VStack(spacing: SophosTheme.Spacing.sm) {
                            UserAvatarView(initials: user.initials, size: 72)

                            Text(user.displayName)
                                .font(SophosTheme.Typography.title3(.semibold))
                                .foregroundColor(SophosTheme.Colors.textPrimary)
                                .multilineTextAlignment(.center)

                            if let email = user.primaryEmail {
                                Text(email)
                                    .font(SophosTheme.Typography.subheadline())
                                    .foregroundColor(SophosTheme.Colors.textSecondary)
                            }

                            // Source badge
                            HStack(spacing: 4) {
                                Image(systemName: user.sourceIcon)
                                    .font(.system(size: 11))
                                Text(user.sourceLabel)
                                    .font(SophosTheme.Typography.caption2(.semibold))
                            }
                            .foregroundColor(SophosTheme.Colors.sophosBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(SophosTheme.Colors.sophosBlue.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(SophosTheme.Spacing.lg)
                        .sophosCard()

                        // Profile details
                        VStack(spacing: 0) {
                            Text("Account Info")
                                .sophosSectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, SophosTheme.Spacing.md)
                                .padding(.bottom, SophosTheme.Spacing.xs)

                            if let first = user.firstName {
                                DetailRow(label: "First Name", value: first)
                                Divider().background(SophosTheme.Colors.divider)
                                    .padding(.leading, SophosTheme.Spacing.md)
                            }
                            if let last = user.lastName {
                                DetailRow(label: "Last Name", value: last)
                                Divider().background(SophosTheme.Colors.divider)
                                    .padding(.leading, SophosTheme.Spacing.md)
                            }
                            if let email = user.email {
                                DetailRow(label: "Email", value: email)
                                Divider().background(SophosTheme.Colors.divider)
                                    .padding(.leading, SophosTheme.Spacing.md)
                            }
                            if let login = user.viaLogin, login != user.email {
                                DetailRow(label: "Login", value: login)
                                Divider().background(SophosTheme.Colors.divider)
                                    .padding(.leading, SophosTheme.Spacing.md)
                            }
                            DetailRow(label: "Source", value: user.sourceLabel)
                            if let created = user.createdDate {
                                Divider().background(SophosTheme.Colors.divider)
                                    .padding(.leading, SophosTheme.Spacing.md)
                                DetailRow(label: "Added", value: created.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                        .sophosCard()

                        // Group memberships
                        VStack(alignment: .leading, spacing: SophosTheme.Spacing.sm) {
                            HStack {
                                Text("Group Memberships")
                                    .sophosSectionHeader()
                                Spacer()
                                if groupsLoading {
                                    ProgressView()
                                        .tint(SophosTheme.Colors.sophosBlue)
                                        .scaleEffect(0.7)
                                } else {
                                    Text("\(groups.count)")
                                        .font(SophosTheme.Typography.caption2(.semibold))
                                        .foregroundColor(SophosTheme.Colors.textTertiary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(SophosTheme.Colors.backgroundCard2)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, SophosTheme.Spacing.md)
                            .padding(.top, SophosTheme.Spacing.sm)

                            if let error = groupsError {
                                HStack(spacing: SophosTheme.Spacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(SophosTheme.Colors.statusWarning)
                                    Text(error)
                                        .font(SophosTheme.Typography.caption())
                                        .foregroundColor(SophosTheme.Colors.textSecondary)
                                    Spacer()
                                    Button("Retry") { Task { await loadGroups() } }
                                        .font(SophosTheme.Typography.caption(.semibold))
                                        .foregroundColor(SophosTheme.Colors.sophosBlue)
                                }
                                .padding(SophosTheme.Spacing.sm)
                            } else if groups.isEmpty && groupsLoaded {
                                HStack(spacing: SophosTheme.Spacing.xs) {
                                    Image(systemName: "person.3")
                                        .foregroundColor(SophosTheme.Colors.textTertiary)
                                    Text("Not a member of any groups")
                                        .font(SophosTheme.Typography.footnote())
                                        .foregroundColor(SophosTheme.Colors.textSecondary)
                                }
                                .padding(SophosTheme.Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(groups) { group in
                                        HStack(spacing: SophosTheme.Spacing.sm) {
                                            Image(systemName: "person.3.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(SophosTheme.Colors.sophosBlue)
                                                .frame(width: 24)
                                            Text(group.name ?? group.id)
                                                .font(SophosTheme.Typography.subheadline())
                                                .foregroundColor(SophosTheme.Colors.textPrimary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, SophosTheme.Spacing.md)
                                        .padding(.vertical, SophosTheme.Spacing.sm)

                                        if group.id != groups.last?.id {
                                            Divider()
                                                .background(SophosTheme.Colors.divider)
                                                .padding(.leading, SophosTheme.Spacing.md + 24 + SophosTheme.Spacing.sm)
                                        }
                                    }
                                }
                            }
                        }
                        .sophosCard()

                        // User ID
                        VStack(alignment: .leading, spacing: SophosTheme.Spacing.xs) {
                            Text("User ID").sophosSectionHeader()
                            Text(user.id)
                                .font(.custom("Menlo", size: 12))
                                .foregroundColor(SophosTheme.Colors.textSecondary)
                                .textSelection(.enabled)
                        }
                        .padding(SophosTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sophosCard()

                        Spacer().frame(height: SophosTheme.Spacing.xl)
                    }
                    .padding(SophosTheme.Spacing.md)
                }
            }
            .navigationTitle("User Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(SophosTheme.Colors.sophosBlue)
                }
            }
        }
        .task { await loadGroups() }
    }

    // MARK: - Load groups

    private func loadGroups() async {
        groupsLoading = true
        groupsError = nil
        defer { groupsLoading = false; groupsLoaded = true }
        do {
            let response = try await api.fetchUserGroups(userId: user.id)
            groups = response.items
        } catch {
            // Non-fatal — user profile still shows; just surface the group error
            groupsError = error.localizedDescription
        }
    }
}
