import Foundation
import SwiftData

@Model
public final class CachedMetric {
    #Unique<CachedMetric>([\.identifier])

    @Attribute(.unique) public var identifier: String
    public var id: String
    public var displayName: String
    public var service: String
    public var action: String
    public var unit: String?
    public var eventCount: Int
    public var mean: Double?
    public var lastEventAt: Date?
    public var lastSyncedAt: Date

    public init(
        id: String,
        identifier: String,
        displayName: String,
        service: String,
        action: String,
        unit: String? = nil,
        eventCount: Int,
        mean: Double? = nil,
        lastEventAt: Date? = nil,
        lastSyncedAt: Date = .init()
    ) {
        self.id = id
        self.identifier = identifier
        self.displayName = displayName
        self.service = service
        self.action = action
        self.unit = unit
        self.eventCount = eventCount
        self.mean = mean
        self.lastEventAt = lastEventAt
        self.lastSyncedAt = lastSyncedAt
    }
}
