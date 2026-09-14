import Foundation

public struct FlintDigestHistoryResponse: Codable, Sendable, Hashable {
    public let data: [FlintDigestSummary]
    public let meta: FlintDigestHistoryMeta
}

public struct FlintDigestSummary: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let localDate: String
    public let period: FlintDigestPeriod?
    public let kind: FlintDigestKind?
    public let title: String
    public let summary: String?
    public let generatedAt: Date?
    public let updatedAt: Date?
    public let unansweredQuestionCount: Int
    public let version: String?
    public let freshness: FlintDigestFreshness?

    enum CodingKeys: String, CodingKey {
        case id, period, kind, title, summary, version, freshness
        case localDate = "local_date"
        case generatedAt = "generated_at"
        case updatedAt = "updated_at"
        case unansweredQuestionCount = "unanswered_question_count"
    }
}

public struct FlintDigestFreshness: Codable, Sendable, Hashable {
    public let state: String
    public let ageSeconds: Int

    enum CodingKeys: String, CodingKey {
        case state
        case ageSeconds = "age_seconds"
    }
}

public struct FlintDigestHistoryMeta: Codable, Sendable, Hashable {
    public let from: String
    public let to: String
    public let effectiveTimezone: String
    public let accountID: String
    public let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case from, to
        case effectiveTimezone = "effective_timezone"
        case accountID = "account_id"
        case nextCursor = "next_cursor"
    }
}

public struct FlintQuestionsResponse: Codable, Sendable, Hashable {
    public let data: [FlintQuestion]
    public let meta: FlintQuestionsMeta
}

public struct FlintQuestion: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let digestID: String
    public let sourceDigest: FlintQuestionSourceDigest
    public let status: FlintQuestionStatus
    public let question: String
    public let topic: String?
    public let answerOptions: [String]?
    public let askedAt: Date?
    public let effectiveAnswer: FlintQuestionEffectiveAnswer?
    public let answerHistory: [FlintQuestionAction]
    public let version: String

    enum CodingKeys: String, CodingKey {
        case id, status, question, topic, version
        case digestID = "digest_id"
        case sourceDigest = "source_digest"
        case answerOptions = "answer_options"
        case askedAt = "asked_at"
        case effectiveAnswer = "effective_answer"
        case answerHistory = "answer_history"
    }

    public var asDigestBlock: FlintDigestBlock {
        FlintDigestBlock(
            id: id,
            blockType: "flint_user_question",
            title: question,
            time: askedAt,
            question: question,
            topic: topic,
            answerOptions: answerOptions,
            answer: effectiveAnswer?.answer,
            answerNote: effectiveAnswer?.context,
            answeredAt: effectiveAnswer?.answeredAt,
            answered: status == .answered
        )
    }
}

public struct FlintQuestionSourceDigest: Codable, Sendable, Hashable {
    public let localDate: String
    public let period: FlintDigestPeriod?

    enum CodingKeys: String, CodingKey {
        case period
        case localDate = "local_date"
    }
}

public enum FlintQuestionStatus: String, Codable, Sendable, Hashable {
    case open
    case answered
    case retired
    case skipped
}

public struct FlintQuestionEffectiveAnswer: Codable, Sendable, Hashable {
    public let answer: String?
    public let context: String?
    public let answeredAt: Date?

    enum CodingKeys: String, CodingKey {
        case answer, context
        case answeredAt = "answered_at"
    }
}

public struct FlintQuestionAction: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let action: FlintQuestionActionKind
    public let answer: String?
    public let context: String?
    public let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, action, answer, context
        case createdAt = "created_at"
    }
}

public enum FlintQuestionActionKind: String, Codable, Sendable, Hashable {
    case answer
    case correct
    case skip
}

public struct FlintQuestionsMeta: Codable, Sendable, Hashable {
    public let nextCursor: String?
    public let effectiveTimezone: String
    public let accountID: String

    enum CodingKeys: String, CodingKey {
        case nextCursor = "next_cursor"
        case effectiveTimezone = "effective_timezone"
        case accountID = "account_id"
    }
}

public struct FlintQuestionActionRequest: Codable, Sendable, Hashable {
    public let action: FlintQuestionActionKind
    public let answer: String?
    public let context: String?

    public init(action: FlintQuestionActionKind, answer: String? = nil, context: String? = nil) {
        self.action = action
        self.answer = answer
        self.context = context
    }
}

public struct FlintQuestionActionResponse: Codable, Sendable, Hashable {
    public let data: FlintQuestion
}
