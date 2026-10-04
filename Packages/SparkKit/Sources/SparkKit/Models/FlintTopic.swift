import Foundation

/// One of Flint's long-lived threads — a strategic, thematic, or tactical
/// topic it tracks across digests (e.g. "US–Iran escalation", "Edinburgh
/// trip with Dan"). Its type and tasks can be edited in the mobile app.
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
    public let version: String?
    public let mentions: [FlintTopicMention]?
    public let tasks: [FlintTopicTask]?
    /// What would move the thread on — the one sentence of it worth a home
    /// screen. Written by the server: explicit when the routine sends one,
    /// otherwise extracted from the closing sentence of `content`.
    public let watchingFor: String?

    enum CodingKeys: String, CodingKey {
        case id, title, content, kind, status, origin, version, mentions, tasks
        case firstSeenAt = "first_seen_at"
        case lastTouchedAt = "last_touched_at"
        case nextReviewAt = "next_review_at"
        case watchingFor = "watching_for"
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
        origin: String? = nil,
        version: String? = nil,
        mentions: [FlintTopicMention]? = nil,
        tasks: [FlintTopicTask]? = nil,
        watchingFor: String? = nil
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
        self.version = version
        self.mentions = mentions
        self.tasks = tasks
        self.watchingFor = watchingFor
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

public struct FlintTopicsResponse: Codable, Sendable, CursorPaged {
    public let data: [FlintTopic]
    public let nextCursor: String?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }

    public init(data: [FlintTopic], nextCursor: String? = nil, hasMore: Bool = false) {
        self.data = data
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        data = try c.decode([FlintTopic].self, forKey: .data)
        nextCursor = try c.decodeIfPresent(String.self, forKey: .nextCursor)
        hasMore = try c.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }
}

public struct FlintTopicResponse: Codable, Sendable, Hashable {
    public let data: FlintTopic
}

/// Calendar dates stay as YYYY-MM-DD strings to avoid shifting a due day across time zones.
public struct FlintTopicTask: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let content: String?
    public let dueOn: String?
    public let reviewOn: String?
    public let completedAt: Date?
    public let version: String

    enum CodingKeys: String, CodingKey {
        case id, title, content, version
        case dueOn = "due_on"
        case reviewOn = "review_on"
        case completedAt = "completed_at"
    }
}

public struct FlintTopicTaskEditRequest: Encodable, Sendable {
    public let title: String
    public let content: String?
    public let dueOn: String?
    public let reviewOn: String?

    enum CodingKeys: String, CodingKey {
        case title, content
        case dueOn = "due_on"
        case reviewOn = "review_on"
    }

    public init(title: String, content: String?, dueOn: String?, reviewOn: String?) {
        self.title = title
        self.content = content
        self.dueOn = dueOn
        self.reviewOn = reviewOn
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        if let content { try container.encode(content, forKey: .content) }
        else { try container.encodeNil(forKey: .content) }
        if let dueOn { try container.encode(dueOn, forKey: .dueOn) }
        else { try container.encodeNil(forKey: .dueOn) }
        if let reviewOn { try container.encode(reviewOn, forKey: .reviewOn) }
        else { try container.encodeNil(forKey: .reviewOn) }
    }
}

public struct FlintTopicTaskResponse: Codable, Sendable {
    public let data: FlintTopicTask
}

public struct FlintTopicTaskRequest: Encodable, Sendable {
    public let clientMutationID: UUID
    public let title: String
    public let content: String?
    public let dueOn: String?
    public let reviewOn: String?

    enum CodingKeys: String, CodingKey {
        case title, content
        case clientMutationID = "client_mutation_id"
        case dueOn = "due_on"
        case reviewOn = "review_on"
    }

    public init(clientMutationID: UUID = UUID(), title: String, content: String? = nil, dueOn: String? = nil, reviewOn: String? = nil) {
        self.clientMutationID = clientMutationID
        self.title = title
        self.content = content
        self.dueOn = dueOn
        self.reviewOn = reviewOn
    }
}

public struct FlintTopicTaskUpdate: Encodable, Sendable {
    public let completed: Bool

    public init(completed: Bool) {
        self.completed = completed
    }
}

public struct FlintTopicMention: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let kind: String?
    public let sourceType: String
    public let digestID: String
    public let blockID: String?
    public let title: String
    public let detail: String?
    public let excerpt: String?
    public let localDate: String?
    public let period: FlintDigestPeriod?
    public let occurredAt: Date?
    public let deepLink: URL?
    public let sourceDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, kind, title, detail, excerpt, period
        case sourceType = "source_type"
        case digestID = "digest_id"
        case blockID = "block_id"
        case localDate = "local_date"
        case occurredAt = "occurred_at"
        case deepLink = "deep_link"
        case sourceDeleted = "source_deleted"
    }
}
