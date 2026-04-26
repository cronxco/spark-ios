import Foundation

/// A single search hit. Decodes a polymorphic backend payload of the form:
/// `{ "kind": "event", "id": "...", "title": "...", ... }`.
public enum SearchResult: Codable, Sendable, Hashable, Identifiable {
    case event(EventHit)
    case object(ObjectHit)
    case block(BlockHit)
    case metric(MetricHit)
    case integration(IntegrationHit)
    case place(PlaceHit)
    case intent(IntentHit)

    public var id: String {
        switch self {
        case .event(let h): "event:\(h.id)"
        case .object(let h): "object:\(h.id)"
        case .block(let h): "block:\(h.id)"
        case .metric(let h): "metric:\(h.identifier)"
        case .integration(let h): "integration:\(h.id)"
        case .place(let h): "place:\(h.id)"
        case .intent(let h): "intent:\(h.id)"
        }
    }

    public var title: String {
        switch self {
        case .event(let h): h.title
        case .object(let h): h.title
        case .block(let h): h.title
        case .metric(let h): h.title
        case .integration(let h): h.title
        case .place(let h): h.title
        case .intent(let h): h.title
        }
    }

    public var subtitle: String? {
        switch self {
        case .event(let h): h.subtitle
        case .object(let h): h.subtitle
        case .block(let h): h.subtitle
        case .metric(let h): h.subtitle
        case .integration(let h): h.subtitle
        case .place(let h): h.subtitle
        case .intent(let h): h.subtitle
        }
    }

    public var sectionLabel: String {
        switch self {
        case .event: "Events"
        case .object: "Objects"
        case .block: "Blocks"
        case .metric: "Metrics"
        case .integration: "Integrations"
        case .place: "Places"
        case .intent: "Actions"
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey { case kind }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        let single = try decoder.singleValueContainer()
        switch kind {
        case "event": self = .event(try single.decode(EventHit.self))
        case "object": self = .object(try single.decode(ObjectHit.self))
        case "block": self = .block(try single.decode(BlockHit.self))
        case "metric": self = .metric(try single.decode(MetricHit.self))
        case "integration": self = .integration(try single.decode(IntegrationHit.self))
        case "place": self = .place(try single.decode(PlaceHit.self))
        case "intent": self = .intent(try single.decode(IntentHit.self))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown search result kind \(kind)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var single = encoder.singleValueContainer()
        switch self {
        case .event(let h): try single.encode(h)
        case .object(let h): try single.encode(h)
        case .block(let h): try single.encode(h)
        case .metric(let h): try single.encode(h)
        case .integration(let h): try single.encode(h)
        case .place(let h): try single.encode(h)
        case .intent(let h): try single.encode(h)
        }
    }

    // MARK: - Hits

    public struct EventHit: Codable, Sendable, Hashable {
        public let id: String
        public let title: String
        public let subtitle: String?
        public let domain: String?
    }

    public struct ObjectHit: Codable, Sendable, Hashable {
        public let id: String
        public let title: String
        public let subtitle: String?
        public let concept: String?
    }

    public struct BlockHit: Codable, Sendable, Hashable {
        public let id: String
        public let title: String
        public let subtitle: String?
        public let blockType: String?

        enum CodingKeys: String, CodingKey {
            case id, title, subtitle
            case blockType = "block_type"
        }
    }

    public struct MetricHit: Codable, Sendable, Hashable {
        public let identifier: String
        public let title: String
        public let subtitle: String?
        public let domain: String?
    }

    public struct IntegrationHit: Codable, Sendable, Hashable {
        public let id: String
        public let title: String
        public let subtitle: String?
        public let service: String?
    }

    public struct PlaceHit: Codable, Sendable, Hashable {
        public let id: String
        public let title: String
        public let subtitle: String?
    }

    public struct IntentHit: Codable, Sendable, Hashable {
        public let id: String
        public let title: String
        public let subtitle: String?
        public let symbol: String?
    }
}
