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

    /// `sync_status` on the wire is a map of service name to that service's
    /// last write, the same shape `HealthDashboard` already models:
    ///
    /// ```json
    /// "sync_status": {
    ///   "oura": { "event_count": 6, "last_event_time": "…", "actions": [...] },
    ///   "apple_health": { "event_count": 13, "last_event_time": "…", "coverage": "partial" }
    /// }
    /// ```
    ///
    /// The flat `up_to_date` / `stale` / `last_event_at` fields this type
    /// started with are kept because `FlintBriefingFacts` reads them, but no
    /// deployed backend sends them — they decode to `nil`, which is why a
    /// service being hours behind never reached the UI. `services` is the one
    /// to read.
    public struct SyncStatus: Codable, Sendable, Hashable {
        public struct Service: Codable, Sendable, Hashable {
            public let eventCount: Int
            public let lastEventTime: Date?
            public let actions: [String]
            public let coverage: String?

            /// The backend says `partial` when it knows a service has only
            /// written some of the day so far.
            public var isPartial: Bool { coverage == "partial" }

            enum CodingKeys: String, CodingKey {
                case coverage, actions
                case eventCount = "event_count"
                case lastEventTime = "last_event_time"
            }

            public init(
                eventCount: Int = 0,
                lastEventTime: Date? = nil,
                actions: [String] = [],
                coverage: String? = nil
            ) {
                self.eventCount = eventCount
                self.lastEventTime = lastEventTime
                self.actions = actions
                self.coverage = coverage
            }

            public init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                eventCount = try c.decodeIfPresent(Int.self, forKey: .eventCount) ?? 0
                lastEventTime = try c.decodeIfPresent(Date.self, forKey: .lastEventTime)
                actions = try c.decodeIfPresent([String].self, forKey: .actions) ?? []
                coverage = try c.decodeIfPresent(String.self, forKey: .coverage)
            }
        }

        public let services: [String: Service]
        public let upToDate: Bool?
        public let stale: [String]?
        public let lastEventAt: Date?

        public init(
            services: [String: Service] = [:],
            upToDate: Bool? = nil,
            stale: [String]? = nil,
            lastEventAt: Date? = nil
        ) {
            self.services = services
            self.upToDate = upToDate
            self.stale = stale
            self.lastEventAt = lastEventAt
        }

        /// The service's last write, or `nil` when it has not reported at all.
        public func lastWrite(_ service: String) -> Date? {
            services[service]?.lastEventTime
        }

        /// Whether `service` has gone quiet for longer than `threshold`, or has
        /// told us outright that its day is partial. A service missing from the
        /// map has not written today and counts as behind.
        public func isBehind(
            _ service: String,
            now: Date = .now,
            threshold: TimeInterval = 3 * 3600
        ) -> Bool {
            guard let entry = services[service] else { return true }
            if entry.isPartial { return true }
            guard let last = entry.lastEventTime else { return true }
            return now.timeIntervalSince(last) > threshold
        }

        // `sync_status` is a free-form map of service names, so the flat legacy
        // keys have to be lifted out of that same container rather than decoded
        // from a fixed CodingKeys set.
        private struct AnyKey: CodingKey {
            let stringValue: String
            var intValue: Int? { nil }
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { return nil }
        }

        private enum Legacy: String {
            case upToDate = "up_to_date"
            case stale
            case lastEventAt = "last_event_at"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)

            var found: [String: Service] = [:]
            var up: Bool?
            var staleList: [String]?
            var lastAt: Date?

            for key in c.allKeys {
                switch Legacy(rawValue: key.stringValue) {
                case .upToDate:
                    up = try? c.decode(Bool.self, forKey: key)
                case .stale:
                    staleList = try? c.decode([String].self, forKey: key)
                case .lastEventAt:
                    lastAt = try? c.decode(Date.self, forKey: key)
                case nil:
                    // Anything else is a service entry. A shape we do not
                    // recognise is skipped rather than failing the whole day.
                    if let service = try? c.decode(Service.self, forKey: key) {
                        found[key.stringValue] = service
                    }
                }
            }

            services = found
            upToDate = up
            stale = staleList
            lastEventAt = lastAt
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: AnyKey.self)
            for (name, service) in services {
                guard let key = AnyKey(stringValue: name) else { continue }
                try c.encode(service, forKey: key)
            }
            if let upToDate, let key = AnyKey(stringValue: Legacy.upToDate.rawValue) {
                try c.encode(upToDate, forKey: key)
            }
            if let stale, let key = AnyKey(stringValue: Legacy.stale.rawValue) {
                try c.encode(stale, forKey: key)
            }
            if let lastEventAt, let key = AnyKey(stringValue: Legacy.lastEventAt.rawValue) {
                try c.encode(lastEventAt, forKey: key)
            }
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
