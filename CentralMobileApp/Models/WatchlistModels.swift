import Foundation
import SwiftData

/// A user-flagged item to track (endpoint, alert, case).
@Model
final class WatchlistItem {
    var itemId: String          // Sophos ID
    var itemType: String        // "endpoint", "alert", "case"
    var name: String
    var detail: String?
    var severity: String?
    var addedAt: Date
    var notes: String?

    init(itemId: String, itemType: String, name: String, detail: String? = nil,
         severity: String? = nil, notes: String? = nil) {
        self.itemId = itemId
        self.itemType = itemType
        self.name = name
        self.detail = detail
        self.severity = severity
        self.addedAt = Date()
        self.notes = notes
    }
}
