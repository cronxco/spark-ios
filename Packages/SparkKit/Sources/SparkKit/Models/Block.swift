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
    /// The plugin's name for the block type, such as "Merchant".
    public let displayName: String?
    /// The plugin's glyph key, such as `fas.store`.
    public let icon: String?
    /// The domain the block's plugin belongs to, such as `money`.
    public let domain: String?
    /// Whether a model wrote the block's text. Nil from older servers.
    public let aiWritten: Bool?
    /// Blocks the plugin keeps out of lists, such as raw payloads.
    public let hidden: Bool
    /// The typed fields the block's card reads. Nil for types without one.
    public let details: BlockDetails?

    enum CodingKeys: String, CodingKey {
        case id, title, time, content, value, unit, references
        case blockType = "block_type"
        case mediaUrl = "media_url"
        case displayName = "display_name"
        case icon, domain, hidden, details
        case aiWritten = "ai_written"
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
        references: [EntityReference]? = nil,
        displayName: String? = nil,
        icon: String? = nil,
        domain: String? = nil,
        aiWritten: Bool? = nil,
        hidden: Bool = false,
        details: BlockDetails? = nil
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
        self.displayName = displayName
        self.icon = icon
        self.domain = domain
        self.aiWritten = aiWritten
        self.hidden = hidden
        self.details = details
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
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        domain = try container.decodeIfPresent(String.self, forKey: .domain)
        aiWritten = try? container.decodeIfPresent(Bool.self, forKey: .aiWritten)
        hidden = (try? container.decodeIfPresent(Bool.self, forKey: .hidden)) ?? false
        // An empty `details` arrives as `[]` from PHP; treat any shape but an object as none.
        details = try? container.decodeIfPresent(BlockDetails.self, forKey: .details)

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
