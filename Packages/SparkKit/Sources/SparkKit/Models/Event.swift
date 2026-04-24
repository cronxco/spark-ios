import Foundation

/// Mirrors `CompactEventResource` on the backend.
public struct Event: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let time: Date?
    public let service: String
    public let domain: String
    public let action: String
    public let value: String?
    public let unit: String?
    public let url: String?
    public let actor: ActorTarget?
    public let target: ActorTarget?

    public struct ActorTarget: Codable, Sendable, Hashable {
        public let id: String
        public let title: String
        public let concept: String

        public init(id: String, title: String, concept: String) {
            self.id = id
            self.title = title
            self.concept = concept
        }
    }

    public init(
        id: String,
        time: Date?,
        service: String,
        domain: String,
        action: String,
        value: String? = nil,
        unit: String? = nil,
        url: String? = nil,
        actor: ActorTarget? = nil,
        target: ActorTarget? = nil
    ) {
        self.id = id
        self.time = time
        self.service = service
        self.domain = domain
        self.action = action
        self.value = value
        self.unit = unit
        self.url = url
        self.actor = actor
        self.target = target
    }
}
