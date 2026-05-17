import Foundation

/// A reference from prose/insight content to another Spark entity.
/// Mirrors the `references` array emitted by `EntityReferenceResolver`
/// on the backend (and the web `<x-event-ref>` chip cards).
public struct EntityReference: Codable, Sendable, Hashable, Identifiable {
    public let type: EntityReferenceType
    public let id: String
    public let title: String
    public let service: String?
    public let domain: String?

    enum CodingKeys: String, CodingKey {
        case type, id, title, service, domain
    }

    public init(
        type: EntityReferenceType,
        id: String,
        title: String,
        service: String? = nil,
        domain: String? = nil
    ) {
        self.type = type
        self.id = id
        self.title = title
        self.service = service
        self.domain = domain
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(EntityReferenceType.self, forKey: .type)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        service = try container.decodeIfPresent(String.self, forKey: .service)
        domain = try container.decodeIfPresent(String.self, forKey: .domain)
    }
}

/// Entity kinds a reference can point at. Unknown values decode to `.unknown`
/// so a new backend type never breaks digest decoding.
public enum EntityReferenceType: String, Codable, Sendable, Hashable, CaseIterable {
    case event
    case object
    case block
    case metric
    case place
    case integration
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = EntityReferenceType(rawValue: raw) ?? .unknown
    }
}
