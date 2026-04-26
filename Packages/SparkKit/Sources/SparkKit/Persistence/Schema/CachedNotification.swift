import Foundation
import SwiftData

@Model
public final class CachedNotification {
    #Unique<CachedNotification>([\.id])

    @Attribute(.unique) public var id: String
    public var title: String
    public var body: String?
    public var domain: String?
    public var isRead: Bool
    public var receivedAt: Date
    public var entityKind: String?
    public var entityId: String?
    public var lastSyncedAt: Date

    public init(
        id: String,
        title: String,
        body: String? = nil,
        domain: String? = nil,
        isRead: Bool = false,
        receivedAt: Date,
        entityKind: String? = nil,
        entityId: String? = nil,
        lastSyncedAt: Date = .init()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.domain = domain
        self.isRead = isRead
        self.receivedAt = receivedAt
        self.entityKind = entityKind
        self.entityId = entityId
        self.lastSyncedAt = lastSyncedAt
    }
}
