import Foundation

/// One of Flint's long-lived threads — a strategic, thematic, or tactical
/// topic it tracks across digests (e.g. "US–Iran escalation", "Edinburgh
/// trip with Dan"). Read-only on the mobile surface; created and maintained
/// by the `manage-flint-topic` MCP tool.
public struct FlintTopic: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let content: String?
    public let kind: FlintTopicKind?
    public let status: FlintTopicStatus?
    public let firstSeenAt: Date?
    public let lastTouchedAt: Date?
    public let nextReviewAt: Date?
    public let origin: String?

    enum CodingKeys: String, CodingKey {
        case id, title, content, kind, status, origin
        case firstSeenAt = "first_seen_at"
        case lastTouchedAt = "last_touched_at"
        case nextReviewAt = "next_review_at"
    }

    public init(
        id: String,
        title: String,
        content: String? = nil,
        kind: FlintTopicKind? = nil,
        status: FlintTopicStatus? = nil,
        firstSeenAt: Date? = nil,
        lastTouchedAt: Date? = nil,
        nextReviewAt: Date? = nil,
        origin: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.kind = kind
        self.status = status
        self.firstSeenAt = firstSeenAt
        self.lastTouchedAt = lastTouchedAt
        self.nextReviewAt = nextReviewAt
        self.origin = origin
    }
}

public enum FlintTopicKind: String, Codable, Sendable, Hashable {
    case strategic
    case thematic
    case tactical
}

public enum FlintTopicStatus: String, Codable, Sendable, Hashable {
    case active
    case dormant
    case resolved
    case expired

    public var isActive: Bool { self == .active }
}

public struct FlintTopicsResponse: Codable, Sendable {
    public let data: [FlintTopic]

    public init(data: [FlintTopic]) {
        self.data = data
    }
}
