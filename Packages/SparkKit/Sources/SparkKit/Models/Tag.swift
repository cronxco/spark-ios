import Foundation

public struct Tag: Codable, Sendable, Hashable, Identifiable {
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

    public init(
        id: String,
        name: String,
        type: String? = nil,
        eventsCount: Int = 0,
        objectsCount: Int = 0,
        totalCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.eventsCount = eventsCount
        self.objectsCount = objectsCount
        self.totalCount = totalCount
    }

    public var eventTag: EventTag {
        EventTag(id: id, name: name, type: type)
    }
}

public struct TagDetailPage: Codable, Sendable {
    public let tag: Tag
    public let data: [SearchResult]
    public let nextCursor: String?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case tag, data
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

public struct TagSuggestions: Codable, Sendable {
    public let data: [Tag]
}

public struct TagMutationResponse: Codable, Sendable {
    public let tag: Tag?
    public let tags: [Tag]
}
