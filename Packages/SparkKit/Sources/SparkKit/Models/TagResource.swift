import Foundation

/// Stable tag resource returned by the Tags API.
public struct TagResource: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let type: String?
    public let eventsCount: Int
    public let objectsCount: Int
    public let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case eventsCount = "events_count"
        case objectsCount = "objects_count"
        case totalCount = "total_count"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? container.decode(String.self, forKey: .id) { id = stringID }
        else { id = String(try container.decode(Int.self, forKey: .id)) }
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        eventsCount = try container.decodeIfPresent(Int.self, forKey: .eventsCount) ?? 0
        objectsCount = try container.decodeIfPresent(Int.self, forKey: .objectsCount) ?? 0
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount) ?? eventsCount + objectsCount
    }

    public var eventTag: EventTag { EventTag(name: name, type: type, tagID: id) }
}

public struct TagPage: Codable, Sendable {
    public let data: [TagResource]
    public let nextCursor: String?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey { case data; case nextCursor = "next_cursor"; case hasMore = "has_more" }
}

/// The API accepts an existing tag ID or resolves a new/existing tag by name.
public struct TagMutationRequest: Codable, Sendable, Hashable {
    public let tagID: String?
    public let name: String?
    public let type: String?

    enum CodingKeys: String, CodingKey {
        case tagID = "tag_id"
        case name, type
    }

    public init(tagID: String) {
        self.tagID = tagID
        name = nil
        type = nil
    }

    public init(name: String, type: String? = nil) {
        tagID = nil
        self.name = name
        self.type = type
    }
}

public struct TagDetailPage: Codable, Sendable {
    public let tag: TagResource
    public let data: [TagDetailItem]
    public let nextCursor: String?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey { case tag, data; case nextCursor = "next_cursor"; case hasMore = "has_more" }
}

/// Compact heterogeneous item returned by `GET /tags/{id}`.
public struct TagDetailItem: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable { case event, object, block }

    public let kind: Kind
    public let id: String
    public let title: String
    public let subtitle: String?
    public let domain: String?
    public let concept: String?
    public let blockType: String?

    enum CodingKeys: String, CodingKey {
        case kind, id, title, subtitle, domain, concept
        case blockType = "block_type"
    }
}
