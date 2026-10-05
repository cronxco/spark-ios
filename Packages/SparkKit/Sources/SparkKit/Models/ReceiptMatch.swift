import Foundation

public struct ReceiptMatch: Decodable, Sendable, Identifiable {
    public let id: String
    public let title: String?
    public let amount: Double?
    public let unit: String?
    public let time: Date?
    public let service: String?
    public let status: String
    public let reason: String?
    public let attemptedAt: Date?
    public let matched: FlintReviewEvent?
    public let candidates: [FlintReviewEvent]

    enum CodingKeys: String, CodingKey {
        case id, title, amount, unit, time, service, status, reason, matched, candidates
        case attemptedAt = "attempted_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        amount = try c.decodeIfPresent(Double.self, forKey: .amount)
        unit = try c.decodeIfPresent(String.self, forKey: .unit)
        time = try c.decodeIfPresent(Date.self, forKey: .time)
        service = try c.decodeIfPresent(String.self, forKey: .service)
        status = try c.decode(String.self, forKey: .status)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        attemptedAt = try c.decodeIfPresent(Date.self, forKey: .attemptedAt)
        matched = try c.decodeIfPresent(FlintReviewEvent.self, forKey: .matched)
        candidates = try c.decodeIfPresent([FlintReviewEvent].self, forKey: .candidates) ?? []
    }

    public func canRetry(at now: Date = .now) -> Bool {
        status != "searching" || (attemptedAt.map { now.timeIntervalSince($0) >= 600 } ?? true)
    }
}

public struct ReceiptMatchResponse: Decodable, Sendable {
    public let data: ReceiptMatch
}

public struct ReceiptMatchListResponse: Decodable, Sendable {
    public let data: [ReceiptMatch]
    public let meta: Page?

    public struct Page: Decodable, Sendable {
        public let currentPage: Int
        public let lastPage: Int
        public let total: Int

        enum CodingKeys: String, CodingKey {
            case total
            case currentPage = "current_page"
            case lastPage = "last_page"
        }
    }
}

public struct ReceiptTransactionListResponse: Decodable, Sendable {
    public let data: [FlintReviewEvent]
}

public struct ReceiptLinkRequest: Encodable, Sendable {
    public let transactionID: String

    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
    }

    public init(transactionID: String) {
        self.transactionID = transactionID
    }
}
