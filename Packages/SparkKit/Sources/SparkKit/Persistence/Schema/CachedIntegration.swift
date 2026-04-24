import Foundation
import SwiftData

@Model
public final class CachedIntegration {
    #Unique<CachedIntegration>([\.id])

    @Attribute(.unique) public var id: String
    public var service: String
    public var name: String
    public var instanceType: String?
    public var status: String
    public var lastSyncedAt: Date

    public init(
        id: String,
        service: String,
        name: String,
        instanceType: String? = nil,
        status: String,
        lastSyncedAt: Date = .init()
    ) {
        self.id = id
        self.service = service
        self.name = name
        self.instanceType = instanceType
        self.status = status
        self.lastSyncedAt = lastSyncedAt
    }
}
