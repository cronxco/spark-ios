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
