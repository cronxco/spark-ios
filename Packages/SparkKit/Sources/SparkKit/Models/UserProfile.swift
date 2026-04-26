import Foundation

public struct UserProfile: Codable, Sendable {
    public let id: String
    public let name: String
    public let email: String
    public let timezone: String?
    public let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, email, timezone
        case avatarURL = "avatar_url"
    }

    public init(id: String, name: String, email: String, timezone: String? = nil, avatarURL: URL? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.timezone = timezone
        self.avatarURL = avatarURL
    }
}
