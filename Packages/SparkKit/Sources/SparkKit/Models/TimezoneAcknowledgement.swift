import Foundation

public struct TimezoneAcknowledgement: Decodable, Sendable, Equatable {
    public let timezone: String
    public let source: String
    public let acknowledgedAt: Date?
    public let eventId: String?
    public let deviceId: String?

    public init(
        timezone: String,
        source: String,
        acknowledgedAt: Date?,
        eventId: String?,
        deviceId: String?
    ) {
        self.timezone = timezone
        self.source = source
        self.acknowledgedAt = acknowledgedAt
        self.eventId = eventId
        self.deviceId = deviceId
    }

    enum CodingKeys: String, CodingKey {
        case timezone
        case source
        case acknowledgedAt = "acknowledged_at"
        case eventId = "event_id"
        case deviceId = "device_id"
    }
}

public struct TimezoneAcknowledgementRequest: Encodable, Sendable, Equatable {
    public let timezone: String
    public let previousTimezone: String?
    public let deviceId: String?

    public init(timezone: String, previousTimezone: String? = nil, deviceId: String? = nil) {
        self.timezone = timezone
        self.previousTimezone = previousTimezone
        self.deviceId = deviceId
    }

    enum CodingKeys: String, CodingKey {
        case timezone
        case previousTimezone = "previous_timezone"
        case deviceId = "device_id"
    }
}

public enum TimezoneChangePolicy {
    public static func rejectionKey(
        acknowledgedTimezone: String,
        deviceTimezone: String
    ) -> String {
        "\(acknowledgedTimezone)\n\(deviceTimezone)"
    }

    public static func shouldPrompt(
        acknowledgedTimezone: String,
        deviceTimezone: String,
        rejectedKey: String?
    ) -> Bool {
        guard acknowledgedTimezone != deviceTimezone else { return false }
        return rejectedKey != rejectionKey(
            acknowledgedTimezone: acknowledgedTimezone,
            deviceTimezone: deviceTimezone
        )
    }
}
