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

    enum CodingKeys: String, CodingKey {
        case id, title, body, domain, entity
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
        entity: EntityRef? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.domain = domain
        self.isRead = isRead
        self.receivedAt = receivedAt
        self.entity = entity
    }
}
