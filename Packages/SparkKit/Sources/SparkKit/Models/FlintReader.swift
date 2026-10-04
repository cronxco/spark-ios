import Foundation

/// `GET /flint/digests?from=…&to=…`.
///
/// Like the questions list, the cursor is top-level on the wire, not inside
/// `meta`, and the client read it from `meta` — so the Flint tab's 30-day
/// history only ever showed the first page. `nextCursor` falls back to
/// `meta.nextCursor` for tolerance.
public struct FlintDigestHistoryResponse: Codable, Sendable, Hashable, CursorPaged {
    public let data: [FlintDigestSummary]
    public let meta: FlintDigestHistoryMeta
    public let nextCursor: String?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case data, meta
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        data = try c.decode([FlintDigestSummary].self, forKey: .data)
        let decodedMeta = try c.decode(FlintDigestHistoryMeta.self, forKey: .meta)
        let cursor = try c.decodeIfPresent(String.self, forKey: .nextCursor) ?? decodedMeta.nextCursor
        meta = decodedMeta
        nextCursor = cursor
        hasMore = try c.decodeIfPresent(Bool.self, forKey: .hasMore) ?? (cursor != nil)
    }
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

/// `GET /flint/questions`.
///
/// The cursor sits at the top level, in the shared envelope — not inside
/// `meta`. The client used to read `meta.next_cursor`, which the server has
/// never sent for this endpoint, so the Flint tab only ever loaded the first
/// page of questions. `meta.nextCursor` is still decoded for tolerance, and
/// `nextCursor` falls back to it.
public struct FlintQuestionsResponse: Codable, Sendable, Hashable, CursorPaged {
    public let data: [FlintQuestion]
    public let meta: FlintQuestionsMeta
    public let nextCursor: String?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case data, meta
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        data = try c.decode([FlintQuestion].self, forKey: .data)
        let decodedMeta = try c.decode(FlintQuestionsMeta.self, forKey: .meta)
        let cursor = try c.decodeIfPresent(String.self, forKey: .nextCursor) ?? decodedMeta.nextCursor
        meta = decodedMeta
        nextCursor = cursor
        hasMore = try c.decodeIfPresent(Bool.self, forKey: .hasMore) ?? (cursor != nil)
    }
}

public struct FlintQuestion: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let digestID: String
    public let sourceDigest: FlintQuestionSourceDigest
    public let status: FlintQuestionStatus
    /// The short label the question carries as a digest block — "The £2,508
    /// transfer from Daniel" — where `question` is the full text.
    public let title: String?
    public let question: String
    public let topic: String?
    public let answerOptions: [String]?
    public let askedAt: Date?
    public let effectiveAnswer: FlintQuestionEffectiveAnswer?
    public let answerHistory: [FlintQuestionAction]
    public let version: String

    enum CodingKeys: String, CodingKey {
        case id, status, title, question, topic, version
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
            title: title ?? question,
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
    /// Nullable on the wire: the server falls back to the digest event's time
    /// and has neither for a block whose event is gone. Non-optional here, one
    /// such question failed the whole page.
    public let localDate: String?
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
