import Foundation

/// Tag metadata attached to compact event payloads.
///
/// The backend now returns `{ name, type }` objects, but older endpoints and
/// cached fixtures may still return plain strings. Decode both shapes so API
/// rollout does not break list/detail screens.
public struct EventTag: Codable, Sendable, Hashable, Identifiable {
    public let name: String
    public let type: String?
    /// Stable backend identifier when the source payload provides one.
    public let tagID: String?

    public var id: String { tagID ?? "\(type ?? ""):\(name)" }

    public init(name: String, type: String? = nil, tagID: String? = nil) {
        self.name = name
        self.type = type
        self.tagID = tagID
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type
    }

    public init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            name = string
            type = nil
            tagID = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        if let stringID = try? container.decode(String.self, forKey: .id) { tagID = stringID }
        else if let numericID = try? container.decode(Int.self, forKey: .id) { tagID = String(numericID) }
        else { tagID = nil }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(tagID, forKey: .id)
    }
}

public extension Array where Element == EventTag {
    var names: [String] {
        map(\.name)
    }
}
