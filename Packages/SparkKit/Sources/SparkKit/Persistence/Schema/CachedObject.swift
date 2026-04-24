import Foundation
import SwiftData

@Model
public final class CachedObject {
    #Unique<CachedObject>([\.id])

    @Attribute(.unique) public var id: String
    public var concept: String
    public var type: String
    public var title: String
    public var time: Date?
    public var content: String?
    public var url: String?
    public var mediaUrl: String?
    public var lastSyncedAt: Date

    public init(
        id: String,
        concept: String,
        type: String,
        title: String,
        time: Date? = nil,
        content: String? = nil,
        url: String? = nil,
        mediaUrl: String? = nil,
        lastSyncedAt: Date = .init()
    ) {
        self.id = id
        self.concept = concept
        self.type = type
        self.title = title
        self.time = time
        self.content = content
        self.url = url
        self.mediaUrl = mediaUrl
        self.lastSyncedAt = lastSyncedAt
    }
}
