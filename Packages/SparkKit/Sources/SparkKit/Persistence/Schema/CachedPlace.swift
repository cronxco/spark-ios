import Foundation
import SwiftData

@Model
public final class CachedPlace {
    #Unique<CachedPlace>([\.id])

    @Attribute(.unique) public var id: String
    public var title: String
    public var type: String?
    public var latitude: Double?
    public var longitude: Double?
    public var address: String?
    public var category: String?
    public var lastSyncedAt: Date

    public init(
        id: String,
        title: String,
        type: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        category: String? = nil,
        lastSyncedAt: Date = .init()
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.category = category
        self.lastSyncedAt = lastSyncedAt
    }
}
