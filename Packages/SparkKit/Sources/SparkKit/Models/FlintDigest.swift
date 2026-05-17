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

    public var isQuestion: Bool { blockType == "flint_user_question" }

    enum CodingKeys: String, CodingKey {
        case id, title, time, content, question, topic, priority, answer, answered, references
        case blockType = "block_type"
        case answerOptions = "answer_options"
        case answerNote = "answer_note"
        case answeredAt = "answered_at"
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
        references: [EntityReference]? = nil
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
