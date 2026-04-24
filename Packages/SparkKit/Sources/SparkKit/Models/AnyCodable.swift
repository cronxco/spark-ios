import Foundation

/// Holds heterogeneous JSON values — used for DaySummary sections whose shape
/// varies by domain. Phase 2 replaces these with typed substructures as the
/// detail views firm up.
public struct AnyCodable: Codable, Sendable, Hashable {
    public let value: Value

    public enum Value: Sendable, Hashable {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case array([AnyCodable])
        case object([String: AnyCodable])
    }

    public init(_ value: Value) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = .null
        } else if let bool = try? container.decode(Bool.self) {
            value = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            value = .int(int)
        } else if let double = try? container.decode(Double.self) {
            value = .double(double)
        } else if let string = try? container.decode(String.self) {
            value = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            value = .array(array)
        } else if let object = try? container.decode([String: AnyCodable].self) {
            value = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case .null: try container.encodeNil()
        case let .bool(v): try container.encode(v)
        case let .int(v): try container.encode(v)
        case let .double(v): try container.encode(v)
        case let .string(v): try container.encode(v)
        case let .array(v): try container.encode(v)
        case let .object(v): try container.encode(v)
        }
    }

    public var stringValue: String? {
        if case let .string(v) = value { return v }
        return nil
    }

    public var intValue: Int? {
        switch value {
        case let .int(v): return v
        case let .double(v): return Int(v)
        default: return nil
        }
    }

    public var doubleValue: Double? {
        switch value {
        case let .int(v): return Double(v)
        case let .double(v): return v
        default: return nil
        }
    }

    public var objectValue: [String: AnyCodable]? {
        if case let .object(v) = value { return v }
        return nil
    }

    public var arrayValue: [AnyCodable]? {
        if case let .array(v) = value { return v }
        return nil
    }
}
