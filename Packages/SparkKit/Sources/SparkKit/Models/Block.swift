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
    public let references: [EntityReference]?

    enum CodingKeys: String, CodingKey {
        case id, title, time, content, value, unit, references
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
        mediaUrl: String? = nil,
        references: [EntityReference]? = nil
    ) {
        self.id = id
        self.blockType = blockType
        self.title = title
        self.time = time
        self.content = content
        self.value = value
        self.unit = unit
        self.mediaUrl = mediaUrl
        self.references = references
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        blockType = try container.decode(String.self, forKey: .blockType)
        title = try container.decode(String.self, forKey: .title)
        time = try container.decodeIfPresent(Date.self, forKey: .time)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        mediaUrl = try container.decodeIfPresent(String.self, forKey: .mediaUrl)
        references = try container.decodeIfPresent([EntityReference].self, forKey: .references)

        if let stringValue = try? container.decodeIfPresent(String.self, forKey: .value) {
            value = stringValue
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .value) {
            value = String(intValue)
        } else if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: .value) {
            value = String(doubleValue)
        } else if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .value) {
            value = String(boolValue)
        } else {
            value = nil
        }
    }
}
