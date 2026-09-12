import Foundation

/// A push or in-app alert delivered to the user. Mirrors
/// `CompactNotificationResource` on the backend.
public struct NotificationItem: Codable, Sendable, Hashable, Identifiable {
    public enum EntityKind: String, Codable, Sendable {
        case event, object, metric, place, anomaly, integration
    }

    public struct EntityRef: Codable, Sendable, Hashable {
        public let kind: EntityKind
        public let id: String

        public init(kind: EntityKind, id: String) {
            self.kind = kind
            self.id = id
        }
    }

    public let id: String
    public let title: String
    public let body: String?
    public let domain: String?
    public let isRead: Bool
    public let receivedAt: Date
    public let entity: EntityRef?

    /// Strong resource version, for `If-Match` on delete.
    ///
    /// Optional so a client stays decodable against a server that predates the
    /// field; a nil version simply means delete cannot be attempted.
    public let version: String?

    enum CodingKeys: String, CodingKey {
        case id, title, body, domain, entity, version
        case isRead = "is_read"
        case receivedAt = "received_at"
    }

    public init(
        id: String,
        title: String,
        body: String? = nil,
        domain: String? = nil,
        isRead: Bool = false,
        receivedAt: Date = .init(),
        entity: EntityRef? = nil,
        version: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.domain = domain
        self.isRead = isRead
        self.receivedAt = receivedAt
        self.entity = entity
        self.version = version
    }
}

/// One row in Spark's unified notification feed. Notification metadata is
/// intentionally carried by the API rather than duplicated into the iOS
/// persistence schema; the existing `CachedNotification` remains the offline
/// cache for durable notification rows.
public struct NotificationFeedItem: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable { case notification, activity }
    public enum Stream: String, Codable, Sendable, CaseIterable { case updates, activity, attention, system }
    public enum Severity: String, Codable, Sendable { case info, success, warning, error, critical }
    public enum State: String, Codable, Sendable {
        case active, completed, failed, resolved, expired, archived
    }

    public struct Progress: Codable, Sendable, Hashable {
        public let current: Int
        public let total: Int
        public let step: String
    }

    public struct Action: Codable, Sendable, Hashable {
        public let id: String
        public let label: String
    }

    public let contractVersion: Int
    public let id: String
    public let kind: Kind
    public let type: String
    public let stream: Stream
    public let severity: Severity
    public let state: State
    public let title: String
    public let body: String?
    public var isRead: Bool
    public let occurrenceCount: Int
    public let occurredAt: Date
    public let updatedAt: Date?
    public let archivedAt: Date?
    public let entity: NotificationItem.EntityRef?
    public let destination: String?
    public let primaryAction: Action?
    public let progress: Progress?
    public let hasTechnicalDetail: Bool
    public let version: String?

    enum CodingKeys: String, CodingKey {
        case id, kind, type, stream, severity, state, title, body, entity, destination, progress, version
        case contractVersion = "contract_version"
        case isRead = "is_read"
        case occurrenceCount = "occurrence_count"
        case occurredAt = "occurred_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
        case primaryAction = "primary_action"
        case hasTechnicalDetail = "has_technical_detail"
    }

    public init(
        contractVersion: Int = 1,
        id: String,
        kind: Kind = .notification,
        type: String = "notification",
        stream: Stream = .updates,
        severity: Severity = .info,
        state: State = .active,
        title: String,
        body: String? = nil,
        isRead: Bool = false,
        occurrenceCount: Int = 1,
        occurredAt: Date = .now,
        updatedAt: Date? = nil,
        archivedAt: Date? = nil,
        entity: NotificationItem.EntityRef? = nil,
        destination: String? = nil,
        primaryAction: Action? = nil,
        progress: Progress? = nil,
        hasTechnicalDetail: Bool = false,
        version: String? = nil
    ) {
        self.contractVersion = contractVersion
        self.id = id
        self.kind = kind
        self.type = type
        self.stream = stream
        self.severity = severity
        self.state = state
        self.title = title
        self.body = body
        self.isRead = isRead
        self.occurrenceCount = occurrenceCount
        self.occurredAt = occurredAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
        self.entity = entity
        self.destination = destination
        self.primaryAction = primaryAction
        self.progress = progress
        self.hasTechnicalDetail = hasTechnicalDetail
        self.version = version
    }
}

public struct NotificationFeedCounts: Codable, Sendable, Hashable {
    public let unread: Int
    public let unresolvedAttention: Int
    public let activeActivity: Int
    public let byStream: [String: Int]

    enum CodingKeys: String, CodingKey {
        case unread
        case unresolvedAttention = "unresolved_attention"
        case activeActivity = "active_activity"
        case byStream = "by_stream"
    }

    public init(unread: Int = 0, unresolvedAttention: Int = 0, activeActivity: Int = 0, byStream: [String: Int] = [:]) {
        self.unread = unread
        self.unresolvedAttention = unresolvedAttention
        self.activeActivity = activeActivity
        self.byStream = byStream
    }
}

public struct NotificationFeedPage: Codable, Sendable {
    public let data: [NotificationFeedItem]
    public let nextCursor: String?
    public let hasMore: Bool
    public let counts: NotificationFeedCounts

    enum CodingKeys: String, CodingKey {
        case data, counts
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}
