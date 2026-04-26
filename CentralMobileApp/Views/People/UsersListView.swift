import SwiftUI

// MARK: - Source filter

private enum UserSourceFilter: String, CaseIterable {
    case all             = "All"
    case activeDirectory = "AD"
    case azureAD         = "Azure AD"
    case sophos          = "Sophos"
    case other           = "Other"

    func matches(_ user: SophosUser) -> Bool {
        let src = (user.sourceType ?? user.source ?? "").lowercased()
        switch self {
        case .all:             return true
        case .activeDirectory: return src.contains("active") && !src.contains("azure")
        case .azureAD:         return src.contains("azure")
        case .sophos:          return src.contains("sophos")
        case .other:           return !src.contains("active") && !src.contains("azure") && !src.contains("sophos")
        }
    }
}

// MARK: - Users List View

struct UsersListView: View {

    @State private var users: [SophosUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var sourceFilter: UserSourceFilter = .all
    @State private var selectedUser: SophosUser?

    private let api = SophosAPIService.shared

    private var filtered: [SophosUser] {
        var list = users
        if sourceFilter != .all {
            list = list.filter { sourceFilter.matches($0) }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                ($0.primaryEmail ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {

                // Source filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SophosTheme.Spacing.xs) {
                        ForEach(UserSourceFilter.allCases, id: \.self) { filter in
                            FilterPill(label: filter.rawValue,
                                       isSelected: sourceFilter == filter) {
                                sourceFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal, SophosTheme.Spacing.md)
                    .padding(.vertical, SophosTheme.Spacing.sm)
                }
                .background(SophosTheme.Colors.navigationBar)

                // Summary bar
                if !users.isEmpty && !isLoading {
                    HStack {
                        Text("\(filtered.count) user\(filtered.count == 1 ? "" : "s")")
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, SophosTheme.Spacing.md)
                    .padding(.vertical, 4)
                    .background(SophosTheme.Colors.backgroundPrimary)
                }

                if isLoading {
                    Spacer()
                    ProgressView().tint(SophosTheme.Colors.sophosBlue)
                    Spacer()
                } else if let error = errorMessage {
                    ErrorView(message: error) { Task { await load() } }
                } else if filtered.isEmpty {
                    Spacer()
                    VStack(spacing: SophosTheme.Spacing.sm) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                        Text("No users found")
                            .font(SophosTheme.Typography.headline())
                            .foregroundColor(SophosTheme.Colors.textPrimary)
                        Text("No users match the current filters.")
                            .font(SophosTheme.Typography.subheadline())
                            .foregroundColor(SophosTheme.Colors.textSecondary)
                    }
                    .padding()
                    Spacer()
                } else {
                    List(filtered) { user in
                        Button { selectedUser = user } label: {
                            UserListRow(user: user)
                        }
                        .listRowBackground(SophosTheme.Colors.backgroundCard)
                        .listRowSeparatorTint(SophosTheme.Colors.divider)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(SophosTheme.Colors.backgroundPrimary)
                    .refreshable { await load() }
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search by name or email…"
        )
        .sheet(item: $selectedUser) { user in
            UserDetailView(user: user)
        }
        .task { await load() }
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.fetchUsers()
            users = response.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - User list row

struct UserListRow: View {
    let user: SophosUser

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {

            // Initials avatar
            UserAvatarView(initials: user.initials, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName)
                    .font(SophosTheme.Typography.subheadline(.semibold))
                    .foregroundColor(SophosTheme.Colors.textPrimary)
                    .lineLimit(1)

                if let email = user.primaryEmail {
                    Text(email)
                        .font(SophosTheme.Typography.caption())
                        .foregroundColor(SophosTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: SophosTheme.Spacing.xs) {
                    Image(systemName: user.sourceIcon)
                        .font(.system(size: 9))
                        .foregroundColor(SophosTheme.Colors.textTertiary)
                    Text(user.sourceLabel)
                        .font(SophosTheme.Typography.caption2())
                        .foregroundColor(SophosTheme.Colors.textTertiary)

                    if let groups = user.groups, !groups.isEmpty {
                        Text("·").foregroundColor(SophosTheme.Colors.textTertiary)
                            .font(SophosTheme.Typography.caption2())
                        Text("\(groups.count) group\(groups.count == 1 ? "" : "s")")
                            .font(SophosTheme.Typography.caption2())
                            .foregroundColor(SophosTheme.Colors.textTertiary)
                    }
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(SophosTheme.Colors.textTertiary)
        }
        .padding(.vertical, SophosTheme.Spacing.xs)
    }
}

// MARK: - User avatar component (shared with detail view)

struct UserAvatarView: View {
    let initials: String
    let size: CGFloat

    // Deterministic colour from initials
    private var avatarColor: Color {
        let colours: [Color] = [
            SophosTheme.Colors.sophosBlue,
            SophosTheme.Colors.statusWarning,
            SophosTheme.Colors.statusHealthy,
            SophosTheme.Colors.severityHigh,
            Color(red: 0.4, green: 0.3, blue: 0.8)
        ]
        let index = abs(initials.hashValue) % colours.count
        return colours[index]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor.opacity(0.2))
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundColor(avatarColor)
        }
    }
}
