import Foundation

/// Cursor-paginated response wrapper used by paginated mobile endpoints.
/// Mirrors the backend's `{ "data": [...], "next_cursor": "..." }` shape.
public struct Page<Item: Codable & Sendable>: Codable, Sendable {
    public let data: [Item]
    public let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }

    public init(data: [Item], nextCursor: String? = nil) {
        self.data = data
        self.nextCursor = nextCursor
    }
}
