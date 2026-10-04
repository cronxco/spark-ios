import Foundation

/// Mirrors `CompactMetricResource` on the backend.
public struct Metric: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let identifier: String
    public let displayName: String
    public let service: String
    public let domain: String?
    public let action: String
    public let unit: String?
    public let eventCount: Int
    public let mean: Double?
    public let lastEventAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, identifier, service, domain, action, unit, mean
        case displayName = "display_name"
        case eventCount = "event_count"
        case lastEventAt = "last_event_at"
    }

    public init(
        id: String,
        identifier: String,
        displayName: String,
        service: String,
        domain: String? = nil,
        action: String,
        unit: String? = nil,
        eventCount: Int,
        mean: Double? = nil,
        lastEventAt: Date? = nil
    ) {
        self.id = id
        self.identifier = identifier
        self.displayName = displayName
        self.service = service
        self.domain = domain
        self.action = action
        self.unit = unit
        self.eventCount = eventCount
        self.mean = mean
        self.lastEventAt = lastEventAt
    }
}
