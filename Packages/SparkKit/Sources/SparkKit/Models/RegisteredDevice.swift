import Foundation

public struct RegisteredDevice: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let platform: String
    public let lastSeenAt: Date?
    public let isCurrentDevice: Bool
    /// Diagnostic fields returned by newer device-list responses. Never expose
    /// the APNs endpoint or token in this model/UI.
    public let deviceType: String?
    public let appEnvironment: String?
    public let bundleID: String?
    public let appVersion: String?
    public let osVersion: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, platform
        case lastSeenAt = "last_seen_at"
        case isCurrentDevice = "is_current_device"
        case deviceType = "device_type"
        case appEnvironment = "app_environment"
        case bundleID = "bundle_id"
        case appVersion = "app_version"
        case osVersion = "os_version"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? container.decode(String.self, forKey: .id) {
            id = stringID
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }
        name = try container.decode(String.self, forKey: .name)
        platform = try container.decode(String.self, forKey: .platform)
        lastSeenAt = try container.decodeIfPresent(Date.self, forKey: .lastSeenAt)
        isCurrentDevice = try container.decodeIfPresent(Bool.self, forKey: .isCurrentDevice) ?? false
        deviceType = try container.decodeIfPresent(String.self, forKey: .deviceType)
        appEnvironment = try container.decodeIfPresent(String.self, forKey: .appEnvironment)
        bundleID = try container.decodeIfPresent(String.self, forKey: .bundleID)
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion)
        osVersion = try container.decodeIfPresent(String.self, forKey: .osVersion)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    public init(id: String, name: String, platform: String, lastSeenAt: Date? = nil, isCurrentDevice: Bool = false, deviceType: String? = nil, appEnvironment: String? = nil, bundleID: String? = nil, appVersion: String? = nil, osVersion: String? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.platform = platform
        self.lastSeenAt = lastSeenAt
        self.isCurrentDevice = isCurrentDevice
        self.deviceType = deviceType
        self.appEnvironment = appEnvironment
        self.bundleID = bundleID
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
