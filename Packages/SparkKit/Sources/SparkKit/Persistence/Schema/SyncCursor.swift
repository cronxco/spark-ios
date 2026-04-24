import Foundation
import SwiftData

/// Per-resource cursor used by the delta-sync engine. Populated in Phase 3 —
/// the model is defined now so the schema is stable from v1.
@Model
public final class SyncCursor {
    #Unique<SyncCursor>([\.resource])

    @Attribute(.unique) public var resource: String
    public var cursor: String?
    public var lastSyncedAt: Date?

    public init(resource: String, cursor: String? = nil, lastSyncedAt: Date? = nil) {
        self.resource = resource
        self.cursor = cursor
        self.lastSyncedAt = lastSyncedAt
    }
}
