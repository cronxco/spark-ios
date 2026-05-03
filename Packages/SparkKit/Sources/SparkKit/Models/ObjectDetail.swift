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
}
