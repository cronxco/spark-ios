import Foundation

/// Mirrors the output of `DaySummaryService::generateSummary()` on the backend.
///
/// Section bodies (`health`, `activity`, `money`, `media`, `knowledge`) vary in
/// shape per domain — they are decoded as `[String: AnyCodable]` for Phase 1.
/// Phase 2 will introduce typed substructures as detail views firm up.
public struct DaySummary: Codable, Sendable, Hashable {
    public let date: String
    public let timezone: String
    public let syncStatus: SyncStatus
    public let sections: Sections
    public let anomalies: [Anomaly]

    enum CodingKeys: String, CodingKey {
        case date, timezone, sections, anomalies
        case syncStatus = "sync_status"
    }

    public struct SyncStatus: Codable, Sendable, Hashable {
        public let upToDate: Bool?
        public let stale: [String]?
        public let lastEventAt: Date?

        enum CodingKeys: String, CodingKey {
            case stale
            case upToDate = "up_to_date"
            case lastEventAt = "last_event_at"
        }
    }

    public struct Sections: Codable, Sendable, Hashable {
        public let health: AnyCodable?
        public let activity: AnyCodable?
        public let money: AnyCodable?
        public let media: AnyCodable?
        public let knowledge: AnyCodable?
    }

    public init(
        date: String,
        timezone: String,
        syncStatus: SyncStatus,
        sections: Sections,
        anomalies: [Anomaly]
    ) {
        self.date = date
        self.timezone = timezone
        self.syncStatus = syncStatus
        self.sections = sections
        self.anomalies = anomalies
    }
}
