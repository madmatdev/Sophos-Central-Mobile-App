import Foundation
import SwiftData

/// A saved Sophos Central tenant for multi-tenant management.
@Model
final class SavedTenant {
    var tenantId: String
    var name: String
    var dataRegionURL: String
    var clientId: String
    var clientSecret: String    // Encrypted via SwiftData + device encryption
    var addedAt: Date
    var isActive: Bool
    var lastHealthScore: Int?
    var lastAlertCount: Int?

    init(tenantId: String, name: String, dataRegionURL: String,
         clientId: String, clientSecret: String) {
        self.tenantId = tenantId
        self.name = name
        self.dataRegionURL = dataRegionURL
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.addedAt = Date()
        self.isActive = false
        self.lastHealthScore = nil
        self.lastAlertCount = nil
    }
}
