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
    public let tldr: String?
    public let actor: ActorTarget?
    public let target: ActorTarget?

    enum CodingKeys: String, CodingKey {
        case id, time, service, domain, action, value, unit, url, tldr, actor, target
    }

    public struct ActorTarget: Codable, Sendable, Hashable {
        public let id: String
        public let title: String
        public let concept: String
        public let mediaUrl: String?

        enum CodingKeys: String, CodingKey {
            case id, title, concept
            case mediaUrl = "media_url"
        }

        public init(id: String, title: String, concept: String, mediaUrl: String? = nil) {
            self.id = id
            self.title = title
            self.concept = concept
            self.mediaUrl = mediaUrl
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
        tldr: String? = nil,
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
        self.tldr = tldr
        self.actor = actor
        self.target = target
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        time = try container.decodeIfPresent(Date.self, forKey: .time)
        service = try container.decode(String.self, forKey: .service)
        domain = try container.decode(String.self, forKey: .domain)
        action = try container.decode(String.self, forKey: .action)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        tldr = try container.decodeIfPresent(String.self, forKey: .tldr)
        actor = try container.decodeIfPresent(ActorTarget.self, forKey: .actor)
        target = try container.decodeIfPresent(ActorTarget.self, forKey: .target)

        if let stringValue = try? container.decodeIfPresent(String.self, forKey: .value) {
            value = stringValue
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .value) {
            value = String(intValue)
        } else if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: .value) {
            value = String(doubleValue)
        } else if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .value) {
            value = String(boolValue)
        } else {
            value = nil
        }
    }
}
