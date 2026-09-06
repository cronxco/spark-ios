import Foundation

public struct NotificationPreferences: Codable, Sendable {
    /// The notification types the backend can gate.
    ///
    /// These raw values must match `NotificationCatalogue::configurableTypes()`
    /// exactly: they are the strings a notification's `getNotificationType()`
    /// returns, which is what `SparkNotification::via()` gates delivery on.
    /// Decoding drops unrecognised keys, so a case missing here silently
    /// removes that toggle from Settings — and the PATCH endpoint requires the
    /// whole set, so an incomplete list is also rejected on save.
    ///
    /// The previous five cases (anomaly, digest, newBookmark, calendarEvent and
    /// integrationFailed) were the mobile API's invention; only
    /// integration_failed named a notification that is ever sent.
    public enum Category: String, Codable, Sendable, CaseIterable {
        case integrationCompleted = "integration_completed"
        case integrationFailed = "integration_failed"
        case integrationAuthenticationFailed = "integration_authentication_failed"
        case cookieExpiryWarning = "cookie_expiry_warning"
        case fetchMultipleFailures = "fetch_multiple_failures"
        case fetchContentChanged = "fetch_content_changed"
        case migrationCompleted = "migration_completed"
        case migrationFailed = "migration_failed"
        case dataExportReady = "data_export_ready"
        case systemMaintenance = "system_maintenance"

        public var displayName: String {
            switch self {
            case .integrationCompleted: "Sync Complete"
            case .integrationFailed: "Sync Failed"
            case .integrationAuthenticationFailed: "Reconnection Needed"
            case .cookieExpiryWarning: "Saved Login Expiring"
            case .fetchMultipleFailures: "Repeated Fetch Failures"
            case .fetchContentChanged: "Tracked Page Changed"
            case .migrationCompleted: "Import Complete"
            case .migrationFailed: "Import Failed"
            case .dataExportReady: "Export Ready"
            case .systemMaintenance: "System Maintenance"
            }
        }

        public var subtitle: String {
            switch self {
            case .integrationCompleted: "When a connected service finishes syncing"
            case .integrationFailed: "When a connected service stops syncing"
            case .integrationAuthenticationFailed: "When a service needs you to sign in again"
            case .cookieExpiryWarning: "When a saved website login is about to expire"
            case .fetchMultipleFailures: "When a tracked page keeps failing to load"
            case .fetchContentChanged: "When a tracked page's content changes"
            case .migrationCompleted: "When a historical import finishes"
            case .migrationFailed: "When a historical import fails"
            case .dataExportReady: "When your data export is ready to download"
            case .systemMaintenance: "Planned maintenance and service updates"
            }
        }
    }

    /// The `UNNotificationCategory` identifiers the app registers.
    ///
    /// Must match `NotificationCatalogue::apnsCategoryIdentifiers()` on the
    /// backend: category matching is case-sensitive, and a category the client
    /// has not registered arrives with no action buttons at all.
    public enum PushCategory: String, Sendable, CaseIterable {
        /// Needs the user to act — reconnect an integration, refresh a login.
        case integrationAttention = "INTEGRATION_ATTENTION"
        /// Informational sync and import outcomes.
        case integrationStatus = "INTEGRATION_STATUS"
        /// Account-level: exports, maintenance, delivery tests.
        case system = "SYSTEM"
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
