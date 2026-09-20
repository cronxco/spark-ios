import Foundation

public struct FlintDigestListResponse: Codable, Sendable, Hashable {
    public let date: String
    public let count: Int
    public let digests: [FlintDigest]
}

public struct FlintDigest: Codable, Sendable, Hashable, Identifiable {
    public let eventID: String
    public let digestObjectID: String?
    public let date: String
    public let period: FlintDigestPeriod?
    public let kind: FlintDigestKind?
    public let title: String
    public let summary: String?
    public let createdAt: Date?
    public let blockCount: Int
    public let unansweredQuestionCount: Int?
    public let version: String?
    public let blocks: [FlintDigestBlock]

    public var id: String { eventID }

    enum CodingKeys: String, CodingKey {
        case date, period, kind, title, summary, version, blocks
        case eventID = "event_id"
        case digestObjectID = "digest_object_id"
        case createdAt = "created_at"
        case blockCount = "block_count"
        case unansweredQuestionCount = "unanswered_question_count"
    }

    public init(
        eventID: String,
        digestObjectID: String? = nil,
        date: String,
        period: FlintDigestPeriod? = nil,
        kind: FlintDigestKind? = nil,
        title: String,
        summary: String? = nil,
        createdAt: Date? = nil,
        blockCount: Int,
        unansweredQuestionCount: Int? = nil,
        version: String? = nil,
        blocks: [FlintDigestBlock]
    ) {
        self.eventID = eventID
        self.digestObjectID = digestObjectID
        self.date = date
        self.period = period
        self.kind = kind
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.blockCount = blockCount
        self.unansweredQuestionCount = unansweredQuestionCount
        self.version = version
        self.blocks = blocks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventID = try container.decodeLossyString(forKey: .eventID)
        digestObjectID = try container.decodeLossyStringIfPresent(forKey: .digestObjectID)
        date = try container.decode(String.self, forKey: .date)
        period = try container.decodeIfPresent(FlintDigestPeriod.self, forKey: .period)
        kind = try container.decodeIfPresent(FlintDigestKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        blockCount = try container.decodeIfPresent(Int.self, forKey: .blockCount) ?? 0
        unansweredQuestionCount = try container.decodeIfPresent(Int.self, forKey: .unansweredQuestionCount)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        blocks = try container.decodeIfPresent([FlintDigestBlock].self, forKey: .blocks) ?? []
    }
}

public struct FlintDigestBlock: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let blockType: String
    public let title: String
    public let time: Date?
    public let content: String?
    public let question: String?
    public let topic: String?
    public let priority: FlintQuestionPriority?
    public let answerOptions: [String]?
    public let answer: String?
    public let answerNote: String?
    public let answeredAt: Date?
    public let answered: Bool
    public let references: [EntityReference]?
    public let dayContext: FlintDayContext?
    /// Structured fields for a news-roundup story. Older digests use `content`.
    public let news: FlintNewsContent?
    /// Link a block points at — reading picks and drops carry one.
    public let url: String?
    /// Estimated read time in whole minutes, for a reading pick.
    public let minutes: Int?

    public var isQuestion: Bool { blockType == "flint_user_question" }

    enum CodingKeys: String, CodingKey {
        case id, title, time, content, question, topic, priority, answer, answered, references
        case url, minutes, news
        case blockType = "block_type"
        case answerOptions = "answer_options"
        case answerNote = "answer_note"
        case answeredAt = "answered_at"
        case dayContext = "day_context"
    }

    public init(
        id: String,
        blockType: String,
        title: String,
        time: Date? = nil,
        content: String? = nil,
        question: String? = nil,
        topic: String? = nil,
        priority: FlintQuestionPriority? = nil,
        answerOptions: [String]? = nil,
        answer: String? = nil,
        answerNote: String? = nil,
        answeredAt: Date? = nil,
        answered: Bool = false,
        references: [EntityReference]? = nil,
        dayContext: FlintDayContext? = nil,
        news: FlintNewsContent? = nil,
        url: String? = nil,
        minutes: Int? = nil
    ) {
        self.id = id
        self.blockType = blockType
        self.title = title
        self.time = time
        self.content = content
        self.question = question
        self.topic = topic
        self.priority = priority
        self.answerOptions = answerOptions
        self.answer = answer
        self.answerNote = answerNote
        self.answeredAt = answeredAt
        self.answered = answered
        self.references = references
        self.dayContext = dayContext
        self.news = news
        self.url = url
        self.minutes = minutes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeLossyString(forKey: .id)
        blockType = try container.decode(String.self, forKey: .blockType)
        title = try container.decode(String.self, forKey: .title)
        time = try container.decodeIfPresent(Date.self, forKey: .time)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        question = try container.decodeIfPresent(String.self, forKey: .question)
        topic = try container.decodeIfPresent(String.self, forKey: .topic)
        priority = try container.decodeIfPresent(FlintQuestionPriority.self, forKey: .priority)
        answerOptions = try container.decodeIfPresent([String].self, forKey: .answerOptions)
        answer = try container.decodeIfPresent(String.self, forKey: .answer)
        answerNote = try container.decodeIfPresent(String.self, forKey: .answerNote)
        answeredAt = try container.decodeIfPresent(Date.self, forKey: .answeredAt)
        answered = try container.decodeIfPresent(Bool.self, forKey: .answered) ?? (answer != nil)
        references = try container.decodeIfPresent([EntityReference].self, forKey: .references)
        dayContext = try container.decodeIfPresent(FlintDayContext.self, forKey: .dayContext)
        news = try container.decodeIfPresent(FlintNewsContent.self, forKey: .news)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        minutes = try container.decodeIfPresent(Int.self, forKey: .minutes)
    }
}

public struct FlintNewsContent: Codable, Sendable, Hashable {
    public let summary: String
    public let sources: [FlintNewsSource]
    public let whyItMatters: String?
    public let whatToWatch: String

    enum CodingKeys: String, CodingKey {
        case summary, sources
        case whyItMatters = "why_it_matters"
        case whatToWatch = "what_to_watch"
    }

    public init(summary: String, sources: [FlintNewsSource], whyItMatters: String? = nil, whatToWatch: String) {
        self.summary = summary
        self.sources = sources
        self.whyItMatters = whyItMatters
        self.whatToWatch = whatToWatch
    }
}

public struct FlintNewsSource: Codable, Sendable, Hashable {
    public let publication: String
    public let position: String

    public init(publication: String, position: String) {
        self.publication = publication
        self.position = position
    }
}

// MARK: - Day context

/// Structured calendar/birthdays/weather attached to a `flint_day_context` block,
/// built by the day-briefing skill from the same grounding it uses for the prose
/// digest. Powers the Up to Speed flow's "Your day" screen.
public struct FlintDayContext: Codable, Sendable, Hashable {
    /// The local day this context describes, `yyyy-MM-dd`.
    ///
    /// Morning and afternoon digests describe today; the evening digest
    /// describes tomorrow, because by then today is over and what the reader
    /// needs from the opener is what happens next. `nil` on digests written
    /// before the field existed, which are all describing today.
    public let date: String?
    public let calendar: [FlintDayContextEvent]
    public let birthdays: [FlintDayContextBirthday]
    public let weather: FlintDayContextWeather?

    /// `yyyy-MM-dd` split into its parts, or nil when the wire value is not
    /// that shape. Deliberately not a `DateFormatter`: a cached formatter
    /// carries its own time zone, and resolving a bare calendar day against
    /// one time zone and then comparing it in another is how "Tomorrow" ends
    /// up labelled "Today" for a reader whose device sits on the other side
    /// of midnight from it.
    private static func dayComponents(from date: String) -> DateComponents? {
        let parts = date.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }

        return DateComponents(year: year, month: month, day: day)
    }

    /// The day this context describes, resolved in `calendar`'s time zone so it
    /// can be compared or displayed in that same calendar. Nil when the digest
    /// names no day, or names one that does not parse.
    public func day(in calendar: Calendar = .current) -> Date? {
        guard let date, let components = Self.dayComponents(from: date) else { return nil }

        // The wire format is always Gregorian, whatever the device is set to;
        // only the time zone is taken from the caller's calendar.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone

        return gregorian.date(from: components)
    }

    /// Whether this context describes the day it is being read on. Drives
    /// whether the opener labels the block "Today" or names another day, and
    /// whether a "yesterday" recap still makes sense beside it.
    ///
    /// A missing or unparseable `date` counts as today: every digest written
    /// before the field existed described the day it was written on, and a
    /// malformed one should not silently relabel the reader's own day.
    public func describesToday(now: Date, calendar: Calendar) -> Bool {
        guard let parsed = day(in: calendar) else { return true }
        return calendar.isDate(parsed, inSameDayAs: now)
    }

    public init(
        date: String? = nil,
        calendar: [FlintDayContextEvent] = [],
        birthdays: [FlintDayContextBirthday] = [],
        weather: FlintDayContextWeather? = nil
    ) {
        self.date = date
        self.calendar = calendar
        self.birthdays = birthdays
        self.weather = weather
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        calendar = try container.decodeIfPresent([FlintDayContextEvent].self, forKey: .calendar) ?? []
        birthdays = try container.decodeIfPresent([FlintDayContextBirthday].self, forKey: .birthdays) ?? []
        weather = try container.decodeIfPresent(FlintDayContextWeather.self, forKey: .weather)
    }

    enum CodingKeys: String, CodingKey {
        case date, calendar, birthdays, weather
    }
}

/// A calendar commitment attributed to Will or Dan. Never a birthday — those
/// live in `FlintDayContext.birthdays` instead, unattributed.
public struct FlintDayContextEvent: Codable, Sendable, Hashable, Identifiable {
    /// "will" or "dan" — the digest always sets this; an unrecognised or
    /// missing value decodes as `.will`, matching the server-side default.
    public enum Person: String, Codable, Sendable, Hashable {
        case will
        case dan
    }

    public let title: String
    public let allDay: Bool
    public let start: Date?
    public let person: Person

    public var id: String { "\(title)-\(start?.timeIntervalSince1970 ?? 0)" }

    enum CodingKeys: String, CodingKey {
        case title, start, person
        case allDay = "all_day"
    }

    public init(title: String, allDay: Bool = false, start: Date? = nil, person: Person = .will) {
        self.title = title
        self.allDay = allDay
        self.start = start
        self.person = person
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        allDay = try container.decodeIfPresent(Bool.self, forKey: .allDay) ?? false
        start = try container.decodeIfPresent(Date.self, forKey: .start)
        // Decode the raw string rather than the enum directly — an unrecognised
        // value should fall back to .will, not fail the whole block decode.
        // The server already normalizes this, but the client shouldn't trust it.
        let personRaw = try container.decodeIfPresent(String.self, forKey: .person)
        person = personRaw.flatMap(Person.init(rawValue:)) ?? .will
    }
}

/// A birthday for today — a fact about the day, not a commitment either
/// person is attending, so it carries no `person` attribution.
public struct FlintDayContextBirthday: Codable, Sendable, Hashable, Identifiable {
    public let title: String
    public var id: String { title }

    public init(title: String) {
        self.title = title
    }
}

public struct FlintDayContextWeather: Codable, Sendable, Hashable {
    public let location: String?
    public let condition: String?
    public let tempHighC: Double?
    public let rainProbabilityPct: Int?

    enum CodingKeys: String, CodingKey {
        case location, condition
        case tempHighC = "temp_high_c"
        case rainProbabilityPct = "rain_probability_pct"
    }

    /// Whether there is actually any weather here to show.
    ///
    /// Every property is optional, so `"weather": {}` decodes to a non-nil
    /// value carrying nothing. Treating that as content put an empty tile with
    /// a default cloud glyph on the opener — and, on an otherwise empty day,
    /// the whole day section with it.
    public var hasContent: Bool {
        location?.isEmpty == false
            || condition?.isEmpty == false
            || tempHighC != nil
            || rainProbabilityPct != nil
    }

    public init(location: String? = nil, condition: String? = nil, tempHighC: Double? = nil, rainProbabilityPct: Int? = nil) {
        self.location = location
        self.condition = condition
        self.tempHighC = tempHighC
        self.rainProbabilityPct = rainProbabilityPct
    }
}

public enum FlintDigestPeriod: String, Codable, CaseIterable, Sendable, Hashable {
    case morning
    case afternoon
    case evening

    public var displayName: String {
        switch self {
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        }
    }
}

public enum FlintQuestionPriority: String, Codable, Sendable, Hashable {
    case low
    case medium
    case high

    public var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

public struct FlintQuestionAnswerRequest: Codable, Sendable, Hashable {
    public let answer: String
    public let answerNote: String?

    enum CodingKeys: String, CodingKey {
        case answer
        case answerNote = "answer_note"
    }

    public init(answer: String, answerNote: String? = nil) {
        self.answer = answer
        self.answerNote = answerNote
    }
}

public struct FlintQuestionAnswerResponse: Codable, Sendable, Hashable {
    public let blockID: String
    public let answer: String
    public let answerNote: String?
    public let answeredAt: Date?

    enum CodingKeys: String, CodingKey {
        case answer
        case blockID = "block_id"
        case answerNote = "answer_note"
        case answeredAt = "answered_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blockID = try container.decodeLossyString(forKey: .blockID)
        answer = try container.decode(String.self, forKey: .answer)
        answerNote = try container.decodeIfPresent(String.self, forKey: .answerNote)
        answeredAt = try container.decodeIfPresent(Date.self, forKey: .answeredAt)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) throws -> String {
        if let string = try? decode(String.self, forKey: key) {
            return string
        }
        if let int = try? decode(Int.self, forKey: key) {
            return String(int)
        }
        if let double = try? decode(Double.self, forKey: key) {
            return String(double)
        }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected string-compatible value"
            )
        )
    }

    /// `contains` first: `decodeNil` reads like an existence probe but is not
    /// one — it reports whether a *present* value is null, and throws
    /// `keyNotFound` when the key is absent. Without the guard an omitted
    /// `digest_object_id` failed the whole `FlintDigest` decode, even though
    /// the property is optional. Every fixture and the server send the key, so
    /// nothing caught it until a payload left it out.
    func decodeLossyStringIfPresent(forKey key: Key) throws -> String? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) {
            return nil
        }
        if let string = try? decode(String.self, forKey: key) {
            return string
        }
        if let int = try? decode(Int.self, forKey: key) {
            return String(int)
        }
        if let double = try? decode(Double.self, forKey: key) {
            return String(double)
        }
        return nil
    }
}
