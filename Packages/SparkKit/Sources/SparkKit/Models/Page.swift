import Foundation

/// Cursor-paginated response wrapper used by paginated mobile endpoints.
/// Mirrors the backend's `{ "data": [...], "next_cursor": "...", "has_more": true }` shape.
public struct Page<Item: Codable & Sendable>: Codable, Sendable {
    public let data: [Item]
    public let nextCursor: String?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }

    public init(data: [Item], nextCursor: String? = nil, hasMore: Bool = false) {
        self.data = data
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}
