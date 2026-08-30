import Foundation

public enum SparkEntityKind: String, Codable, Sendable, CaseIterable { case events, objects, blocks }

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
    enum CodingKeys: String, CodingKey {
        case id, type, value, metadata
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
}

public struct LocationRequest: Codable, Sendable { public let latitude: Double; public let longitude: Double; public let address: String? }
public struct GeocodeLocationRequest: Codable, Sendable { public let address: String }

public struct CheckInTimezone: Codable, Sendable, Hashable { public let timezone: String; public let source: String }
public struct MetricBaselinesResponse: Codable, Sendable { public let data: [MetricBaseline] }
public struct MetricBaseline: Codable, Sendable, Identifiable { public let identifier: String; public let displayName: String; public let mean: Double; public let stddev: Double; public let lowerBound: Double; public let upperBound: Double; public let windowDays: Int; public let updatedAt: Date?; public var id: String { identifier }; enum CodingKeys: String, CodingKey { case identifier, mean, stddev; case displayName = "display_name", lowerBound = "lower_bound", upperBound = "upper_bound", windowDays = "window_days", updatedAt = "updated_at" } }
