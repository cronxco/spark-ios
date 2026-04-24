import Foundation
import SwiftData

@Model
public final class CachedEvent {
    #Unique<CachedEvent>([\.id])

    @Attribute(.unique) public var id: String
    public var time: Date?
    public var service: String
    public var domain: String
    public var action: String
    public var value: String?
    public var unit: String?
    public var url: String?
    public var actorTitle: String?
    public var targetTitle: String?
    public var lastSyncedAt: Date

    public init(
        id: String,
        time: Date?,
        service: String,
        domain: String,
        action: String,
        value: String? = nil,
        unit: String? = nil,
        url: String? = nil,
        actorTitle: String? = nil,
        targetTitle: String? = nil,
        lastSyncedAt: Date = .init()
    ) {
        self.id = id
        self.time = time
        self.service = service
        self.domain = domain
        self.action = action
        self.value = value
        self.unit = unit
        self.url = url
        self.actorTitle = actorTitle
        self.targetTitle = targetTitle
        self.lastSyncedAt = lastSyncedAt
    }
}
