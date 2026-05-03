import Foundation

public struct NotificationPreferences: Codable, Sendable {
    public enum Category: String, Codable, Sendable, CaseIterable {
        case anomaly
        case digest
        case integrationFailed = "integration_failed"
        case newBookmark = "new_bookmark"
        case calendarEvent = "calendar_event"

        public var displayName: String {
            switch self {
            case .anomaly: "Anomaly Alerts"
            case .digest: "Daily Digest"
            case .integrationFailed: "Integration Failures"
            case .newBookmark: "New Bookmarks"
            case .calendarEvent: "Calendar Events"
            }
        }

        public var subtitle: String {
            switch self {
            case .anomaly: "When a baseline shifts unexpectedly"
            case .digest: "A summary of your day each morning"
            case .integrationFailed: "When a connected service stops syncing"
            case .newBookmark: "When Spark saves something from the web"
            case .calendarEvent: "Reminders before upcoming meetings"
            }
        }
    }

    public enum DeliveryMode: String, Codable, Sendable, CaseIterable {
        case immediate
        case workHours = "work_hours"
        case dailyDigest = "daily_digest"

        public var displayName: String {
            switch self {
            case .immediate: "Immediate"
            case .workHours: "Work Hours"
            case .dailyDigest: "Daily Digest"
            }
        }
    }

    public var categories: [Category: Bool]
    public var deliveryMode: DeliveryMode
    public var digestTime: String?

    enum CodingKeys: String, CodingKey {
        case categories
        case deliveryMode = "delivery_mode"
        case digestTime = "digest_time"
    }

    public init(categories: [Category: Bool] = [:], deliveryMode: DeliveryMode = .immediate, digestTime: String? = nil) {
        self.categories = categories
        self.deliveryMode = deliveryMode
        self.digestTime = digestTime
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deliveryMode = try container.decodeIfPresent(DeliveryMode.self, forKey: .deliveryMode) ?? .immediate
        digestTime = try container.decodeIfPresent(String.self, forKey: .digestTime)
        let raw = try container.decodeIfPresent([String: Bool].self, forKey: .categories) ?? [:]
        var cats: [Category: Bool] = [:]
        for (key, value) in raw {
            if let cat = Category(rawValue: key) {
                cats[cat] = value
            }
        }
        categories = cats
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deliveryMode, forKey: .deliveryMode)
        try container.encodeIfPresent(digestTime, forKey: .digestTime)
        let raw = Dictionary(uniqueKeysWithValues: categories.map { ($0.key.rawValue, $0.value) })
        try container.encode(raw, forKey: .categories)
    }
}
