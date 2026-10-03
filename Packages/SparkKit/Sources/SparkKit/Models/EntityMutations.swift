import Foundation

/// Entity kinds as they appear in URL collection segments (`/events/{id}`).
public enum SparkEntityKind: String, Codable, Sendable, CaseIterable {
    case events, objects, blocks

    /// The singular kind the API expects in request and response bodies.
    public var payloadValue: String {
        switch self {
        case .events: "event"
        case .objects: "object"
        case .blocks: "block"
        }
    }
}

/// A resource version a mutation changed, so the caller can replace the ETag it holds.
public struct ResourceVersionReference: Codable, Sendable, Hashable {
    public let kind: String
    public let id: String
    public let etag: String

    public init(kind: String, id: String, etag: String) {
        self.kind = kind
        self.id = id
        self.etag = etag
    }
}

public extension Array where Element == ResourceVersionReference {
    func etag(for kind: SparkEntityKind, id: String) -> String? {
        first { $0.kind == kind.payloadValue && $0.id == id }?.etag
    }
}

/// A relationship type the server's registry accepts.
public struct RelationshipTypeOption: Codable, Sendable, Hashable, Identifiable {
    public let type: String
    public let displayName: String
    public let description: String?
    public let isDirectional: Bool
    public let supportsValue: Bool
    public let defaultValueUnit: String?
    public var id: String { type }
    enum CodingKeys: String, CodingKey {
        case type, description
        case displayName = "display_name", isDirectional = "is_directional"
        case supportsValue = "supports_value", defaultValueUnit = "default_value_unit"
    }
}

public struct RelationshipTypesResponse: Codable, Sendable { public let data: [RelationshipTypeOption] }

public struct EntityRelationship: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let fromType: String
    public let fromID: String
    public let toType: String
    public let toID: String
    public let type: String
    public let value: Double?
    public let valueMultiplier: Double?
    public let valueUnit: String?
    public let metadata: [String: AnyCodable]?
    /// The edge's own version; deleting it requires this, not the parent's.
    public let etag: String?
    /// Versions of the entities a create changed (present on create responses).
    public let versions: [ResourceVersionReference]?
    enum CodingKeys: String, CodingKey {
        case id, type, value, metadata, etag, versions
        case fromType = "from_type", fromID = "from_id", toType = "to_type", toID = "to_id"
        case valueMultiplier = "value_multiplier", valueUnit = "value_unit"
    }
}

public struct RelationshipListResponse: Codable, Sendable { public let data: [EntityRelationship] }

public struct RelationshipCreateRequest: Codable, Sendable {
    public let toKind: SparkEntityKind
    public let toID: String
    public let type: String
    public let value: Double?
    public let valueMultiplier: Double?
    public let valueUnit: String?
    public let metadata: [String: AnyCodable]?
    enum CodingKeys: String, CodingKey {
        case toKind = "to_kind", toID = "to_id", type, value
        case valueMultiplier = "value_multiplier", valueUnit = "value_unit", metadata
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .toKind)
        guard let toKind = SparkEntityKind.allCases.first(where: { $0.payloadValue == kind || $0.rawValue == kind }) else {
            throw DecodingError.dataCorruptedError(forKey: .toKind, in: container, debugDescription: "Unknown entity kind \(kind)")
        }
        self.toKind = toKind
        toID = try container.decode(String.self, forKey: .toID)
        type = try container.decode(String.self, forKey: .type)
        value = try container.decodeIfPresent(Double.self, forKey: .value)
        valueMultiplier = try container.decodeIfPresent(Double.self, forKey: .valueMultiplier)
        valueUnit = try container.decodeIfPresent(String.self, forKey: .valueUnit)
        metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toKind.payloadValue, forKey: .toKind)
        try container.encode(toID, forKey: .toID)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(valueMultiplier, forKey: .valueMultiplier)
        try container.encodeIfPresent(valueUnit, forKey: .valueUnit)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
    public init(toKind: SparkEntityKind, toID: String, type: String, value: Double? = nil, valueMultiplier: Double? = nil, valueUnit: String? = nil, metadata: [String: AnyCodable]? = nil) {
        self.toKind = toKind
        self.toID = toID
        self.type = type
        self.value = value
        self.valueMultiplier = valueMultiplier
        self.valueUnit = valueUnit
        self.metadata = metadata
    }
}

public struct LocationRequest: Codable, Sendable { public let latitude: Double; public let longitude: Double; public let address: String?; public init(latitude: Double, longitude: Double, address: String? = nil) { self.latitude = latitude; self.longitude = longitude; self.address = address } }
public struct GeocodeLocationRequest: Codable, Sendable { public let address: String }

public struct CheckInTimezone: Codable, Sendable, Hashable { public let timezone: String; public let source: String }
public struct MetricBaselinesResponse: Codable, Sendable { public let data: [MetricBaseline] }
public struct MetricBaseline: Codable, Sendable, Identifiable { public let identifier: String; public let displayName: String; public let mean: Double; public let stddev: Double; public let lowerBound: Double; public let upperBound: Double; public let windowDays: Int; public let updatedAt: Date?; public var id: String { identifier }; enum CodingKeys: String, CodingKey { case identifier, mean, stddev; case displayName = "display_name", lowerBound = "lower_bound", upperBound = "upper_bound", windowDays = "window_days", updatedAt = "updated_at" } }
