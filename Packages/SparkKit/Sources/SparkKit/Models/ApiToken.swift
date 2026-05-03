import Foundation

public struct ApiToken: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let abilities: [String]
    public let lastUsedAt: Date?
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, abilities
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
    }

    public init(id: String, name: String, abilities: [String], lastUsedAt: Date? = nil, createdAt: Date) {
        self.id = id
        self.name = name
        self.abilities = abilities
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
    }
}

/// Returned exactly once on token creation — contains the plaintext secret.
public struct CreatedApiToken: Codable, Sendable {
    public let id: String
    public let name: String
    public let plaintext: String

    public init(id: String, name: String, plaintext: String) {
        self.id = id
        self.name = name
        self.plaintext = plaintext
    }
}
