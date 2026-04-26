import Foundation

public struct RegisteredDevice: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let platform: String
    public let lastSeenAt: Date?
    public let isCurrentDevice: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, platform
        case lastSeenAt = "last_seen_at"
        case isCurrentDevice = "is_current_device"
    }

    public init(id: String, name: String, platform: String, lastSeenAt: Date? = nil, isCurrentDevice: Bool = false) {
        self.id = id
        self.name = name
        self.platform = platform
        self.lastSeenAt = lastSeenAt
        self.isCurrentDevice = isCurrentDevice
    }
}
