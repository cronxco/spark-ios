import Foundation
import SwiftData

@Model
public final class CachedBlock {
    #Unique<CachedBlock>([\.id])

    @Attribute(.unique) public var id: String
    public var blockType: String
    public var title: String
    public var time: Date?
    public var content: String?
    public var value: String?
    public var unit: String?
    public var mediaUrl: String?
    public var lastSyncedAt: Date

    public init(
        id: String,
        blockType: String,
        title: String,
        time: Date? = nil,
        content: String? = nil,
        value: String? = nil,
        unit: String? = nil,
        mediaUrl: String? = nil,
        lastSyncedAt: Date = .init()
    ) {
        self.id = id
        self.blockType = blockType
        self.title = title
        self.time = time
        self.content = content
        self.value = value
        self.unit = unit
        self.mediaUrl = mediaUrl
        self.lastSyncedAt = lastSyncedAt
    }
}
