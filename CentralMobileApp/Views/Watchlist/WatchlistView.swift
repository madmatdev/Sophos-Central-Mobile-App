import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchlistItem.addedAt, order: .reverse) private var items: [WatchlistItem]
    @State private var filterType: String? = nil

    private let types = ["endpoint", "alert", "case"]

    var filteredItems: [WatchlistItem] {
        guard let filter = filterType else { return items }
        return items.filter { $0.itemType == filter }
    }

    var body: some View {
        ZStack {
            SophosTheme.Colors.backgroundPrimary.ignoresSafeArea()

            if items.isEmpty {
                ContentUnavailableView {
                    Label("No Watched Items", systemImage: "eye")
                } description: {
                    Text("Tap the eye icon on any alert, device, or case to add it to your watchlist.")
                }
            } else {
                VStack(spacing: 0) {
                    // Filter bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: SophosTheme.Spacing.xs) {
                            FilterChip(label: "All", isSelected: filterType == nil) {
                                filterType = nil
                            }
                            ForEach(types, id: \.self) { type in
                                FilterChip(
                                    label: type.capitalized + "s",
                                    isSelected: filterType == type
                                ) {
                                    filterType = type
                                }
                            }
                        }
                        .padding(.horizontal, SophosTheme.Spacing.md)
                        .padding(.vertical, SophosTheme.Spacing.sm)
                    }

                    List {
                        ForEach(filteredItems) { item in
                            WatchlistRow(item: item)
                                .listRowBackground(SophosTheme.Colors.backgroundCard)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Watchlist")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !items.isEmpty {
                    Text("\(filteredItems.count)")
                        .font(SophosTheme.Typography.footnote(.semibold))
                        .foregroundStyle(SophosTheme.Colors.textSecondary)
                }
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredItems[index])
        }
    }
}

// MARK: - Watchlist Row

struct WatchlistRow: View {
    let item: WatchlistItem

    var body: some View {
        HStack(spacing: SophosTheme.Spacing.sm) {
            Image(systemName: iconForType(item.itemType))
                .foregroundStyle(colorForType(item.itemType))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(SophosTheme.Typography.body(.semibold))
                    .foregroundStyle(SophosTheme.Colors.textPrimary)

                if let detail = item.detail {
                    Text(detail)
                        .font(SophosTheme.Typography.caption2())
                        .foregroundStyle(SophosTheme.Colors.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: SophosTheme.Spacing.xs) {
                    Text(item.itemType.capitalized)
                        .font(SophosTheme.Typography.caption2())
                        .foregroundStyle(SophosTheme.Colors.textTertiary)

                    Text("·")
                        .foregroundStyle(SophosTheme.Colors.textTertiary)

                    Text(item.addedAt, style: .relative)
                        .font(SophosTheme.Typography.caption2())
                        .foregroundStyle(SophosTheme.Colors.textTertiary)
                }
            }

            Spacer()

            if let severity = item.severity {
                SeverityBadge(severity: severity)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "endpoint": return "laptopcomputer"
        case "alert":    return "bell.badge"
        case "case":     return "exclamationmark.shield"
        default:         return "eye"
        }
    }

    private func colorForType(_ type: String) -> Color {
        switch type {
        case "endpoint": return SophosTheme.Colors.sophosBlue
        case "alert":    return SophosTheme.Colors.statusCritical
        case "case":     return SophosTheme.Colors.statusWarning
        default:         return SophosTheme.Colors.textSecondary
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(SophosTheme.Typography.caption2(.semibold))
                .padding(.horizontal, SophosTheme.Spacing.sm)
                .padding(.vertical, SophosTheme.Spacing.xxs)
                .background(isSelected ? SophosTheme.Colors.sophosBlue : SophosTheme.Colors.backgroundCard)
                .foregroundStyle(isSelected ? .white : SophosTheme.Colors.textSecondary)
                .clipShape(Capsule())
        }
    }
}
