import Foundation

/// Tag metadata attached to compact event payloads.
///
/// The backend now returns `{ name, type }` objects, but older endpoints and
/// cached fixtures may still return plain strings. Decode both shapes so API
/// rollout does not break list/detail screens.
public struct EventTag: Codable, Sendable, Hashable, Identifiable {
    public let serverID: String?
    public let name: String
    public let type: String?

    public var id: String { serverID ?? "\(type ?? ""):\(name)" }

    public init(id: String? = nil, name: String, type: String? = nil) {
        serverID = id
        self.name = name
        self.type = type
    }

    enum CodingKeys: String, CodingKey {
        case serverID = "id"
        case name, type
    }

    public init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            serverID = nil
            name = string
            type = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        serverID = try container.decodeIfPresent(String.self, forKey: .serverID)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
    }
}

public extension Array where Element == EventTag {
    var names: [String] {
        map(\.name)
    }
}
