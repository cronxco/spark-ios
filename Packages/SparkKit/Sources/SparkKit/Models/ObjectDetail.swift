import Foundation

/// Richer object payload returned by `/api/v1/mobile/objects/{id}`. Wraps
/// the compact `EventObject` and adds related events / objects counts.
public struct ObjectDetail: Codable, Sendable, Hashable, Identifiable {
    public let object: EventObject
    public let recentEvents: [Event]
    public let relatedObjects: [Related]
    public let tags: [String]
    public let aiSummary: String?

    public var id: String { object.id }

    public struct Related: Codable, Sendable, Hashable, Identifiable {
        public let id: String
        public let title: String
        public let concept: String
        public let relationship: String?

        public init(id: String, title: String, concept: String, relationship: String? = nil) {
            self.id = id
            self.title = title
            self.concept = concept
            self.relationship = relationship
        }
    }

    enum CodingKeys: String, CodingKey {
        case object, tags
        case recentEvents = "recent_events"
        case relatedObjects = "related_objects"
        case aiSummary = "summary_ai"
    }

    public init(
        object: EventObject,
        recentEvents: [Event] = [],
        relatedObjects: [Related] = [],
        tags: [String] = [],
        aiSummary: String? = nil
    ) {
        self.object = object
        self.recentEvents = recentEvents
        self.relatedObjects = relatedObjects
        self.tags = tags
        self.aiSummary = aiSummary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Backend may return either an ObjectDetail envelope or a flat
        // EventObject payload with detail fields at the root.
        object = try container.decodeIfPresent(EventObject.self, forKey: .object)
            ?? EventObject(from: decoder)
        recentEvents = try container.decodeIfPresent([Event].self, forKey: .recentEvents) ?? []
        relatedObjects = try container.decodeIfPresent([Related].self, forKey: .relatedObjects) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        aiSummary = try container.decodeIfPresent(String.self, forKey: .aiSummary)
    }
}
