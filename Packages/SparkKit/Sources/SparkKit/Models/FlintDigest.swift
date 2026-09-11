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
    public let title: String
    public let summary: String?
    public let createdAt: Date?
    public let blockCount: Int
    public let unansweredQuestionCount: Int?
    public let blocks: [FlintDigestBlock]

    public var id: String { eventID }

    enum CodingKeys: String, CodingKey {
        case date, period, title, summary, blocks
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
        title: String,
        summary: String? = nil,
        createdAt: Date? = nil,
        blockCount: Int,
        unansweredQuestionCount: Int? = nil,
        blocks: [FlintDigestBlock]
    ) {
        self.eventID = eventID
        self.digestObjectID = digestObjectID
        self.date = date
        self.period = period
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.blockCount = blockCount
        self.unansweredQuestionCount = unansweredQuestionCount
        self.blocks = blocks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventID = try container.decodeLossyString(forKey: .eventID)
        digestObjectID = try container.decodeLossyStringIfPresent(forKey: .digestObjectID)
        date = try container.decode(String.self, forKey: .date)
        period = try container.decodeIfPresent(FlintDigestPeriod.self, forKey: .period)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        blockCount = try container.decodeIfPresent(Int.self, forKey: .blockCount) ?? 0
        unansweredQuestionCount = try container.decodeIfPresent(Int.self, forKey: .unansweredQuestionCount)
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

    public var isQuestion: Bool { blockType == "flint_user_question" }

    enum CodingKeys: String, CodingKey {
        case id, title, time, content, question, topic, priority, answer, answered, references
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
        dayContext: FlintDayContext? = nil
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
    }
}

// MARK: - Day context

/// Structured calendar/birthdays/weather attached to a `flint_day_context` block,
/// built by the day-briefing skill from the same grounding it uses for the prose
/// digest. Powers the Up to Speed flow's "Your day" screen.
public struct FlintDayContext: Codable, Sendable, Hashable {
    public let calendar: [FlintDayContextEvent]
    public let birthdays: [FlintDayContextBirthday]
    public let weather: FlintDayContextWeather?

    public init(
        calendar: [FlintDayContextEvent] = [],
        birthdays: [FlintDayContextBirthday] = [],
        weather: FlintDayContextWeather? = nil
    ) {
        self.calendar = calendar
        self.birthdays = birthdays
        self.weather = weather
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calendar = try container.decodeIfPresent([FlintDayContextEvent].self, forKey: .calendar) ?? []
        birthdays = try container.decodeIfPresent([FlintDayContextBirthday].self, forKey: .birthdays) ?? []
        weather = try container.decodeIfPresent(FlintDayContextWeather.self, forKey: .weather)
    }

    enum CodingKeys: String, CodingKey {
        case calendar, birthdays, weather
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

    func decodeLossyStringIfPresent(forKey key: Key) throws -> String? {
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
