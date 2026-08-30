import Foundation

/// Tag metadata attached to compact event payloads.
///
/// The backend now returns `{ name, type }` objects, but older endpoints and
/// cached fixtures may still return plain strings. Decode both shapes so API
/// rollout does not break list/detail screens.
public struct EventTag: Codable, Sendable, Hashable, Identifiable {
    public let name: String
    public let type: String?

    public var id: String { "\(type ?? ""):\(name)" }

    public init(name: String, type: String? = nil) {
        self.name = name
        self.type = type
    }

    enum CodingKeys: String, CodingKey {
        case name, type
    }

    public init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            name = string
            type = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
    }
}

public extension Array where Element == EventTag {
    var names: [String] {
        map(\.name)
    }
}
