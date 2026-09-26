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
    /// Every connected integration appears, including one with nothing to
    /// report for the day (`event_count` 0, `last_event_time` null), and each
    /// carries the server's own freshness judgement — `stale` and `as_of` —
    /// so the client never infers "behind" from a timestamp and a threshold.
    ///
    /// The flat `up_to_date` / `stale` / `last_event_at` fields this type
    /// started with are kept because `FlintBriefingFacts` reads them, but no
    /// deployed backend sends them. `services` is the one to read.
    public struct SyncStatus: Codable, Sendable, Hashable {
        public struct Service: Codable, Sendable, Hashable {
            public let eventCount: Int
            /// `nil` for a service that is connected but has written nothing
            /// for this day — which is not the same as being behind.
            public let lastEventTime: Date?
            public let actions: [String]
            /// `complete` or `partial`, and only for services whose data
            /// arrives through the day rather than in one batch — today just
            /// `apple_health`. Absent everywhere else.
            public let coverage: String?
            /// The server's reason when `coverage` is partial, fit to show.
            public let coverageNote: String?
            /// The server's judgement that this service is behind for the day,
            /// using the cadence it knows the integration runs at. `nil` from a
            /// server that predates the field.
            public let stale: Bool?
            /// When the server last successfully reached the service. Distinct
            /// from `lastEventTime`: a service can be perfectly in sync and
            /// simply have nothing to report.
            public let asOf: Date?

            /// The backend says `partial` when it knows a service has only
            /// written some of the day so far.
            public var isPartial: Bool { coverage == "partial" }

            enum CodingKeys: String, CodingKey {
                case coverage, actions, stale
                case eventCount = "event_count"
                case lastEventTime = "last_event_time"
                case coverageNote = "coverage_note"
                case asOf = "as_of"
            }

            public init(
                eventCount: Int = 0,
                lastEventTime: Date? = nil,
                actions: [String] = [],
                coverage: String? = nil,
                coverageNote: String? = nil,
                stale: Bool? = nil,
                asOf: Date? = nil
            ) {
                self.eventCount = eventCount
                self.lastEventTime = lastEventTime
                self.actions = actions
                self.coverage = coverage
                self.coverageNote = coverageNote
                self.stale = stale
                self.asOf = asOf
            }

            public init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                eventCount = try c.decodeIfPresent(Int.self, forKey: .eventCount) ?? 0
                lastEventTime = try c.decodeIfPresent(Date.self, forKey: .lastEventTime)
                actions = try c.decodeIfPresent([String].self, forKey: .actions) ?? []
                coverage = try c.decodeIfPresent(String.self, forKey: .coverage)
                coverageNote = try c.decodeIfPresent(String.self, forKey: .coverageNote)
                stale = try c.decodeIfPresent(Bool.self, forKey: .stale)
                asOf = try c.decodeIfPresent(Date.self, forKey: .asOf)
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

        /// Whether the day's figures for `service` should not be trusted yet:
        /// the server says its day is only partly in, or — for a service
        /// with no day-level coverage — that it is stale.
        ///
        /// Both judgements are the server's. There is deliberately no clock
        /// arithmetic here — the server knows each integration's cadence and
        /// the client does not. A service absent from the map is not
        /// connected, which is nothing to wait on.
        ///
        /// Where the server publishes `coverage` it is the finer judgement of
        /// the two, and it wins: Apple Health is pushed rather than polled,
        /// and servers before push tracking called it stale all day long
        /// while also calling its day complete.
        public func isBehind(_ service: String) -> Bool {
            guard let entry = services[service] else { return false }
            if entry.coverage != nil { return entry.isPartial }
            return entry.stale == true
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

        public init(
            health: AnyCodable? = nil,
            activity: AnyCodable? = nil,
            money: AnyCodable? = nil,
            media: AnyCodable? = nil,
            knowledge: AnyCodable? = nil
        ) {
            self.health = health
            self.activity = activity
            self.money = money
            self.media = media
            self.knowledge = knowledge
        }
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
