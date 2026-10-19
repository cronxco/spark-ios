import Foundation

/// What a free-text log entry is about. Matches `ManualLogService::KINDS` on the backend.
public enum LogKind: String, Codable, Sendable, CaseIterable, Hashable {
    case wine
    case beer
    case tv
    case cinema
    case boardGame = "board_game"
}

/// How a beer was served. Matches `AlcoholUnits::SERVING_ML` on the backend.
public enum LogServing: String, Codable, Sendable, CaseIterable, Hashable {
    case draft
    case cask
    case can
    case bottle
    case crowler
    case growler
    case taster
}

/// The body of `POST /log`: one thing the user had or watched, already
/// extracted from their words. The idempotency key makes a retry replay the
/// original events instead of logging twice.
public struct LogRequest: Codable, Sendable, Hashable {
    public var kind: LogKind
    public var idempotencyKey: String
    public var title: String
    public var occurredAt: Date?
    public var quantity: Double?
    public var unit: String?
    public var serving: LogServing?
    public var volumeML: Int?
    public var rating: Double?
    public var notes: String?
    public var season: Int?
    public var episodes: [Int]?
    public var tvdbID: Int?

    public init(
        kind: LogKind,
        idempotencyKey: String = UUID().uuidString,
        title: String,
        occurredAt: Date? = nil,
        quantity: Double? = nil,
        unit: String? = nil,
        serving: LogServing? = nil,
        volumeML: Int? = nil,
        rating: Double? = nil,
        notes: String? = nil,
        season: Int? = nil,
        episodes: [Int]? = nil,
        tvdbID: Int? = nil
    ) {
        self.kind = kind
        self.idempotencyKey = idempotencyKey
        self.title = title
        self.occurredAt = occurredAt
        self.quantity = quantity
        self.unit = unit
        self.serving = serving
        self.volumeML = volumeML
        self.rating = rating
        self.notes = notes
        self.season = season
        self.episodes = episodes
        self.tvdbID = tvdbID
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case idempotencyKey = "idempotency_key"
        case title
        case occurredAt = "occurred_at"
        case quantity
        case unit
        case serving
        case volumeML = "volume_ml"
        case rating
        case notes
        case season
        case episodes
        case tvdbID = "tvdb_id"
    }
}

/// One event written by `POST /log`.
public struct LoggedEvent: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let action: String
    public let title: String?
    public let time: String?

    public init(id: String, action: String, title: String? = nil, time: String? = nil) {
        self.id = id
        self.action = action
        self.title = title
        self.time = time
    }
}

/// A question the backend needs answered before it can log (which series, which season).
public struct LogClarification: Codable, Sendable, Hashable {
    public enum Field: String, Codable, Sendable, Hashable {
        case series
        case season
    }

    public struct Option: Codable, Sendable, Hashable, Identifiable {
        public let label: String
        /// The TheTVDB series id for `series`, or the season number for `season`.
        public let value: Int
        public let overview: String?
        public let image: String?

        public var id: Int { value }

        public init(label: String, value: Int, overview: String? = nil, image: String? = nil) {
            self.label = label
            self.value = value
            self.overview = overview
            self.image = image
        }
    }

    public let field: Field
    public let question: String
    public let options: [Option]
    /// The option to preselect, when the backend has a good guess (the latest season).
    public let suggested: Int?

    public init(field: Field, question: String, options: [Option], suggested: Int? = nil) {
        self.field = field
        self.question = question
        self.options = options
        self.suggested = suggested
    }
}

/// The result of `POST /log`: the events written, or a question to answer first.
public enum LogResponse: Decodable, Sendable, Hashable {
    case logged(events: [LoggedEvent], missingEpisodes: [Int])
    case needsClarification(LogClarification)

    private enum CodingKeys: String, CodingKey {
        case status
        case events
        case missingEpisodes = "missing_episodes"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(String.self, forKey: .status)

        switch status {
        case "logged":
            self = .logged(
                events: try container.decodeIfPresent([LoggedEvent].self, forKey: .events) ?? [],
                missingEpisodes: try container.decodeIfPresent([Int].self, forKey: .missingEpisodes) ?? []
            )
        case "needs_clarification":
            self = .needsClarification(try LogClarification(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .status,
                in: container,
                debugDescription: "Unknown log status \(status)"
            )
        }
    }
}

/// A body that is read only for its `ETag`, so Undo can take the event's current version without decoding the whole detail.
public struct LogEventVersion: Decodable, Sendable, Hashable {
    public init(from decoder: Decoder) throws {}
}
