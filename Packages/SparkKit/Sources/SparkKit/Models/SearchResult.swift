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

/// Search payload returned by `/search`.
/// Backend returns a grouped object: `{ mode, query, events: [...], objects: [...], integrations: [...], metrics: [...] }`.
/// Legacy flat-array and wrapped-array formats are also accepted for backwards compatibility.
public struct SearchResponse: Codable, Sendable, Hashable {
    public let results: [SearchResult]

    enum CodingKeys: String, CodingKey {
        // Grouped backend format
        case events, objects, integrations, metrics
        // Legacy wrapped formats
        case results, data, items, hits
    }

    public init(results: [SearchResult]) {
        self.results = results
    }

    public init(from decoder: Decoder) throws {
        // 1. Raw array (must be checked before requesting a keyed container)
        if let direct = try? [SearchResult](from: decoder) {
            results = direct
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 2. Grouped backend format: { events: [...], objects: [...], ... }
        if container.contains(.events) || container.contains(.objects)
            || container.contains(.integrations) || container.contains(.metrics) {
            var all: [SearchResult] = []

            for e in (try container.decodeIfPresent([BackendEvent].self, forKey: .events)) ?? [] {
                all.append(.event(SearchResult.EventHit(
                    id: e.id ?? "",
                    title: e.target?.title ?? e.action ?? e.service ?? e.id ?? "",
                    subtitle: e.domain,
                    domain: e.domain
                )))
            }
            for o in (try container.decodeIfPresent([BackendObject].self, forKey: .objects)) ?? [] {
                all.append(.object(SearchResult.ObjectHit(
                    id: o.id ?? "",
                    title: o.title ?? o.concept ?? o.id ?? "",
                    subtitle: o.concept,
                    concept: o.concept
                )))
            }
            for i in (try container.decodeIfPresent([BackendIntegration].self, forKey: .integrations)) ?? [] {
                all.append(.integration(SearchResult.IntegrationHit(
                    id: i.id ?? "",
                    title: i.name ?? i.service ?? i.id ?? "",
                    subtitle: i.service,
                    service: i.service
                )))
            }
            for m in (try container.decodeIfPresent([BackendMetric].self, forKey: .metrics)) ?? [] {
                all.append(.metric(SearchResult.MetricHit(
                    identifier: m.identifier ?? "",
                    title: m.displayName ?? m.identifier ?? "",
                    subtitle: m.unit,
                    domain: m.service
                )))
            }

            results = all
            return
        }

        // 3. Legacy wrapped formats
        if let wrapped = try container.decodeIfPresent([SearchResult].self, forKey: .results) {
            results = wrapped; return
        }
        if let wrapped = try container.decodeIfPresent([SearchResult].self, forKey: .data) {
            results = wrapped; return
        }
        if let wrapped = try container.decodeIfPresent([SearchResult].self, forKey: .items) {
            results = wrapped; return
        }
        if let wrapped = try container.decodeIfPresent([SearchResult].self, forKey: .hits) {
            results = wrapped; return
        }

        throw DecodingError.typeMismatch(
            [SearchResult].self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected search payload as grouped object, array, or wrapped array."
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var single = encoder.singleValueContainer()
        try single.encode(results)
    }
}

// MARK: - Private backend compact types

private struct BackendEvent: Decodable {
    let id: String?
    let service: String?
    let domain: String?
    let action: String?
    let target: TargetRef?
    struct TargetRef: Decodable { let title: String? }
}

private struct BackendObject: Decodable {
    let id: String?
    let title: String?
    let concept: String?
}

private struct BackendIntegration: Decodable {
    let id: String?
    let name: String?
    let service: String?
}

private struct BackendMetric: Decodable {
    let identifier: String?
    let displayName: String?
    let unit: String?
    let service: String?

    enum CodingKeys: String, CodingKey {
        case identifier
        case displayName = "display_name"
        case unit
        case service
    }
}
