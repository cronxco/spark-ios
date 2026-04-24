import Foundation

/// Mirrors `CompactBlockResource` on the backend.
public struct Block: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let blockType: String
    public let title: String
    public let time: Date?
    public let content: String?
    public let value: String?
    public let unit: String?
    public let mediaUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, title, time, content, value, unit
        case blockType = "block_type"
        case mediaUrl = "media_url"
    }

    public init(
        id: String,
        blockType: String,
        title: String,
        time: Date? = nil,
        content: String? = nil,
        value: String? = nil,
        unit: String? = nil,
        mediaUrl: String? = nil
    ) {
        self.id = id
        self.blockType = blockType
        self.title = title
        self.time = time
        self.content = content
        self.value = value
        self.unit = unit
        self.mediaUrl = mediaUrl
    }
}
