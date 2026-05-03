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
    public let note: String?
    public let metadata: [AnyCodable]?

    public var id: String { event.id }

    public struct ActorTarget: Codable, Sendable, Hashable {
        public let id: String?
        public let title: String
        public let subtitle: String?
        public let concept: String?
        public let type: String?
        public let content: String?
        public let mediaUrl: String?

        enum CodingKeys: String, CodingKey {
            case id, title, subtitle, concept, type, content
            case mediaUrl = "media_url"
        }

        public init(id: String? = nil, title: String, subtitle: String? = nil, concept: String? = nil, type: String? = nil, content: String? = nil, mediaUrl: String? = nil) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.concept = concept
            self.type = type
            self.content = content
            self.mediaUrl = mediaUrl
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
        case event, actor, target, blocks, related, tags, location, note, metadata
        case aiSummary = "summary_ai"
    }

    enum NoteAliasCodingKeys: String, CodingKey {
        case notes
    }

    public init(
        event: Event,
        actor: ActorTarget? = nil,
        target: ActorTarget? = nil,
        blocks: [Block] = [],
        related: [RelatedEvent] = [],
        tags: [String] = [],
        aiSummary: String? = nil,
        location: Location? = nil,
        note: String? = nil,
        metadata: [AnyCodable]? = nil
    ) {
        self.event = event
        self.actor = actor
        self.target = target
        self.blocks = blocks
        self.related = related
        self.tags = tags
        self.aiSummary = aiSummary
        self.location = location
        self.note = note
        self.metadata = metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let noteAliases = try decoder.container(keyedBy: NoteAliasCodingKeys.self)

        // Backend may return either an EventDetail envelope or a flat Event payload.
        let rootEvent = try container.decodeIfPresent(Event.self, forKey: .event) ?? Event(from: decoder)
        event = rootEvent

        actor = try container.decodeIfPresent(ActorTarget.self, forKey: .actor)
            ?? rootEvent.actor.map {
                ActorTarget(id: $0.id, title: $0.title, subtitle: nil, concept: $0.concept, type: nil, mediaUrl: $0.mediaUrl)
            }
        target = try container.decodeIfPresent(ActorTarget.self, forKey: .target)
            ?? rootEvent.target.map {
                ActorTarget(id: $0.id, title: $0.title, subtitle: nil, concept: $0.concept, type: nil, mediaUrl: $0.mediaUrl)
            }
        blocks = try container.decodeIfPresent([Block].self, forKey: .blocks) ?? []
        related = try container.decodeIfPresent([RelatedEvent].self, forKey: .related) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        aiSummary = try container.decodeIfPresent(String.self, forKey: .aiSummary)
        location = try container.decodeIfPresent(Location.self, forKey: .location)
        note = try container.decodeIfPresent(String.self, forKey: .note)
            ?? noteAliases.decodeIfPresent(String.self, forKey: .notes)
        metadata = try container.decodeIfPresent([AnyCodable].self, forKey: .metadata)
    }
}
