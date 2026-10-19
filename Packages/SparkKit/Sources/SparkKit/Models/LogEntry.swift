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
    /// Names of the people it was shared with. The backend links each one to the events.
    public var people: [String]?
    /// Asks the backend what logging this would match, without writing anything.
    public var dryRun: Bool?
    /// The Vivino or Untappd card the user picked in the preview, so enrichment follows their choice.
    public var matchURL: String?

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
        tvdbID: Int? = nil,
        people: [String]? = nil,
        dryRun: Bool? = nil,
        matchURL: String? = nil
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
        self.people = people
        self.dryRun = dryRun
        self.matchURL = matchURL
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
        case people = "with"
        case dryRun = "dry_run"
        case matchURL = "match_url"
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

/// A person tagged on a logged event, matched to someone known or created on the spot.
public struct LoggedPerson: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let created: Bool

    public init(id: String, name: String, created: Bool = false) {
        self.id = id
        self.name = name
        self.created = created
    }
}

/// What the backend would match for a request, from a dry run.
public struct LogMatch: Decodable, Sendable, Hashable {
    public enum State: String, Decodable, Sendable, Hashable {
        /// A card or series covers the name.
        case matched
        /// Nothing covers it, but these come close.
        case candidates
        case none
        /// The site or TheTVDB could not be searched.
        case unavailable
    }

    /// A Vivino wine or Untappd beer.
    public struct Card: Decodable, Sendable, Hashable, Identifiable {
        public let title: String
        public let detail: String?
        public let rating: Double?
        public let url: String?
        public let image: String?
        /// How much of the typed name the card's title covers, 0 to 1.
        public let score: Double

        public var id: String { url ?? title }

        public init(title: String, detail: String? = nil, rating: Double? = nil, url: String? = nil, image: String? = nil, score: Double = 1) {
            self.title = title
            self.detail = detail
            self.rating = rating
            self.url = url
            self.image = image
            self.score = score
        }
    }

    public struct Series: Decodable, Sendable, Hashable {
        public let id: Int
        public let name: String

        public init(id: Int, name: String) {
            self.id = id
            self.name = name
        }
    }

    public struct Episode: Decodable, Sendable, Hashable, Identifiable {
        public let number: Int
        public let name: String?
        public let aired: String?

        public var id: Int { number }

        public init(number: Int, name: String? = nil, aired: String? = nil) {
            self.number = number
            self.name = name
            self.aired = aired
        }
    }

    public let kind: String
    public let state: State
    public let best: Card?
    public let candidates: [Card]
    public let series: Series?
    public let season: Int?
    public let episodes: [Episode]
    public let missingEpisodes: [Int]

    public init(
        kind: String,
        state: State,
        best: Card? = nil,
        candidates: [Card] = [],
        series: Series? = nil,
        season: Int? = nil,
        episodes: [Episode] = [],
        missingEpisodes: [Int] = []
    ) {
        self.kind = kind
        self.state = state
        self.best = best
        self.candidates = candidates
        self.series = series
        self.season = season
        self.episodes = episodes
        self.missingEpisodes = missingEpisodes
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case state
        case best
        case candidates
        case series
        case season
        case episodes
        case missingEpisodes = "missing_episodes"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(String.self, forKey: .kind)
        state = try container.decode(State.self, forKey: .state)
        best = try container.decodeIfPresent(Card.self, forKey: .best)
        candidates = try container.decodeIfPresent([Card].self, forKey: .candidates) ?? []
        series = try container.decodeIfPresent(Series.self, forKey: .series)
        season = try container.decodeIfPresent(Int.self, forKey: .season)
        episodes = try container.decodeIfPresent([Episode].self, forKey: .episodes) ?? []
        missingEpisodes = try container.decodeIfPresent([Int].self, forKey: .missingEpisodes) ?? []
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
    case logged(events: [LoggedEvent], missingEpisodes: [Int], people: [LoggedPerson])
    case needsClarification(LogClarification)
    /// A dry run: what would match. Nil for kinds with nothing to look up (cinema, board games).
    case preview(LogMatch?)

    private enum CodingKeys: String, CodingKey {
        case status
        case events
        case missingEpisodes = "missing_episodes"
        case people
        case match
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(String.self, forKey: .status)

        switch status {
        case "logged":
            self = .logged(
                events: try container.decodeIfPresent([LoggedEvent].self, forKey: .events) ?? [],
                missingEpisodes: try container.decodeIfPresent([Int].self, forKey: .missingEpisodes) ?? [],
                people: try container.decodeIfPresent([LoggedPerson].self, forKey: .people) ?? []
            )
        case "needs_clarification":
            self = .needsClarification(try LogClarification(from: decoder))
        case "preview":
            self = .preview(try container.decodeIfPresent(LogMatch.self, forKey: .match))
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
