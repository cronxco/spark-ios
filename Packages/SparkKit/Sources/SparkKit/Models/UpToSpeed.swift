import Foundation

// MARK: - Item type discriminator

public enum UpToSpeedItemType: String, Codable, Sendable {
    case flintDigest = "flint_digest"
    case checkIn = "check_in"
    case anomaly
    case newsSummary = "news_summary"
}

// MARK: - Lightweight payload structs

/// Lightweight flint digest summary from the Up to Speed feed.
/// Call FlintEndpoint.digest(id:) with the item id to get the full block list.
public struct UpToSpeedFlintDigestSummary: Codable, Sendable {
    public let date: String
    public let period: FlintDigestPeriod?
    public let title: String?
    public let summary: String?
    public let blockCount: Int
    public let unansweredQuestionCount: Int

    enum CodingKeys: String, CodingKey {
        case date, period, title, summary
        case blockCount = "block_count"
        case unansweredQuestionCount = "unanswered_question_count"
    }

    public init(
        date: String,
        period: FlintDigestPeriod? = nil,
        title: String? = nil,
        summary: String? = nil,
        blockCount: Int,
        unansweredQuestionCount: Int
    ) {
        self.date = date
        self.period = period
        self.title = title
        self.summary = summary
        self.blockCount = blockCount
        self.unansweredQuestionCount = unansweredQuestionCount
    }
}

/// Lightweight check-in status payload from the Up to Speed feed.
/// Both morning and afternoon periods are always present.
public struct UpToSpeedCheckInSummary: Codable, Sendable {
    public let period: CheckInPeriod
    public let date: String
    public let completed: Bool
    public let eventId: String?

    enum CodingKeys: String, CodingKey {
        case period, date, completed
        case eventId = "event_id"
    }

    public init(period: CheckInPeriod, date: String, completed: Bool, eventId: String? = nil) {
        self.period = period
        self.date = date
        self.completed = completed
        self.eventId = eventId
    }
}

/// News/newsletter article summary payload.
/// tldr, summary, and keyTakeaways may be nil if the corresponding block was absent.
public struct NewsSummary: Codable, Sendable {
    public let title: String
    public let source: String
    public let url: String?
    public let time: Date?
    public let tldr: String?
    public let summary: String?
    public let keyTakeaways: String?

    enum CodingKeys: String, CodingKey {
        case title, source, url, time, tldr, summary
        case keyTakeaways = "key_takeaways"
    }

    public init(
        title: String,
        source: String,
        url: String? = nil,
        time: Date? = nil,
        tldr: String? = nil,
        summary: String? = nil,
        keyTakeaways: String? = nil
    ) {
        self.title = title
        self.source = source
        self.url = url
        self.time = time
        self.tldr = tldr
        self.summary = summary
        self.keyTakeaways = keyTakeaways
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        source = try container.decode(String.self, forKey: .source)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        time = try container.decodeIfPresent(Date.self, forKey: .time)
        tldr = try container.decodeIfPresent(String.self, forKey: .tldr)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)

        // key_takeaways may arrive as a JSON array or a pre-formatted string
        if let array = try? container.decode([String].self, forKey: .keyTakeaways) {
            keyTakeaways = array
                .map { $0.hasPrefix("- ") ? $0 : "- \($0)" }
                .joined(separator: "\n")
        } else {
            keyTakeaways = try container.decodeIfPresent(String.self, forKey: .keyTakeaways)
        }
    }
}

// MARK: - Typed payload union

public enum UpToSpeedPayload: Sendable {
    case flintDigest(UpToSpeedFlintDigestSummary)
    case checkIn(UpToSpeedCheckInSummary)
    case anomaly(Anomaly)
    case newsSummary(NewsSummary)
}

// MARK: - Item

public struct UpToSpeedItem: Sendable, Identifiable {
    public let id: String
    public let type: UpToSpeedItemType
    public let caughtUpAt: Date?
    public let payload: UpToSpeedPayload
}

extension UpToSpeedItem: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, type
        case caughtUpAt = "caught_up_at"
        case payload
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decode(UpToSpeedItemType.self, forKey: .type)
        caughtUpAt = try c.decodeIfPresent(Date.self, forKey: .caughtUpAt)

        switch type {
        case .flintDigest:
            payload = .flintDigest(try c.decode(UpToSpeedFlintDigestSummary.self, forKey: .payload))
        case .checkIn:
            payload = .checkIn(try c.decode(UpToSpeedCheckInSummary.self, forKey: .payload))
        case .anomaly:
            payload = .anomaly(try c.decode(Anomaly.self, forKey: .payload))
        case .newsSummary:
            payload = .newsSummary(try c.decode(NewsSummary.self, forKey: .payload))
        }
    }
}

// MARK: - Response

public struct UpToSpeedResponse: Decodable, Sendable {
    public let items: [UpToSpeedItem]
}

// MARK: - Read refs

public struct UpToSpeedReadRef: Encodable, Sendable {
    public let type: String
    public let id: String

    public init(type: UpToSpeedItemType, id: String) {
        self.type = type.rawValue
        self.id = id
    }
}

public struct UpToSpeedMarkReadResponse: Decodable, Sendable {
    public let marked: Int
}

// MARK: - Anomaly acknowledge

public struct AnomalyAcknowledgeRequest: Encodable, Sendable {
    public let note: String?
    public let suppressUntil: String?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public init(note: String?, suppressUntil: Date?) {
        self.note = note.flatMap { $0.isEmpty ? nil : $0 }
        self.suppressUntil = suppressUntil.map { Self.dateFormatter.string(from: $0) }
    }

    enum CodingKeys: String, CodingKey {
        case note
        case suppressUntil = "suppress_until"
    }
}

public struct AnomalyAcknowledgeResponse: Decodable, Sendable {
    public let acknowledged: Bool
}
