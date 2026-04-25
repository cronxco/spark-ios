import Foundation

/// Richer event payload returned by `/api/v1/mobile/events/{id}`. Wraps the
/// compact `Event` and adds the relations the detail screen needs.
///
/// Every relation field is optional/empty-tolerant — backend rollout may
/// land in stages, and the view should degrade gracefully.
public struct EventDetail: Codable, Sendable, Hashable, Identifiable {
    public let event: Event
    public let actor: ActorTarget?
    public let target: ActorTarget?
    public let blocks: [Block]
    public let related: [RelatedEvent]
    public let tags: [String]
    public let aiSummary: String?
    public let location: Location?

    public var id: String { event.id }

    public struct ActorTarget: Codable, Sendable, Hashable {
        public let id: String?
        public let title: String
        public let subtitle: String?
        public let concept: String?
        public let type: String?

        public init(id: String? = nil, title: String, subtitle: String? = nil, concept: String? = nil, type: String? = nil) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.concept = concept
            self.type = type
        }
    }

    public struct RelatedEvent: Codable, Sendable, Hashable, Identifiable {
        public let id: String
        public let title: String
        public let meta: String?
        public let time: Date?

        public init(id: String, title: String, meta: String? = nil, time: Date? = nil) {
            self.id = id
            self.title = title
            self.meta = meta
            self.time = time
        }
    }

    public struct Location: Codable, Sendable, Hashable {
        public let lat: Double
        public let lng: Double

        public init(lat: Double, lng: Double) {
            self.lat = lat
            self.lng = lng
        }
    }

    enum CodingKeys: String, CodingKey {
        case event, actor, target, blocks, related, tags, location
        case aiSummary = "summary_ai"
    }

    public init(
        event: Event,
        actor: ActorTarget? = nil,
        target: ActorTarget? = nil,
        blocks: [Block] = [],
        related: [RelatedEvent] = [],
        tags: [String] = [],
        aiSummary: String? = nil,
        location: Location? = nil
    ) {
        self.event = event
        self.actor = actor
        self.target = target
        self.blocks = blocks
        self.related = related
        self.tags = tags
        self.aiSummary = aiSummary
        self.location = location
    }
}
