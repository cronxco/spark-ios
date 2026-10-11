import Foundation

/// Amounts on the money plan endpoints are integer pence, unlike the account endpoints.
public struct MoneyPlanResponse: Decodable, Sendable {
    public let data: MoneyPlan
}

public struct MoneyPlan: Decodable, Sendable {
    public let safeToSpend: SafeToSpend
    public let cover: CardCover
    public let budgets: [BudgetProgress]
    public let strip: PlanStrip
    public let pots: [PlanPot]
    public let interest: [InterestMonth]
    public let bufferEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case safeToSpend = "safe_to_spend"
        case cover, budgets, strip, pots, interest
        case bufferEnabled = "buffer_enabled"
    }
}

public struct SafeToSpend: Decodable, Sendable {
    public let available: Int
    public let owedOnCards: Int
    public let amount: Int

    enum CodingKeys: String, CodingKey {
        case available
        case owedOnCards = "owed_on_cards"
        case amount
    }
}

public struct CardCover: Decodable, Sendable {
    public enum Status: String, Decodable, Sendable {
        case covered
        case short
        case noBuffer = "no_buffer"
    }

    public struct BufferPot: Decodable, Sendable {
        public let id: String
        public let name: String
        public let balance: Int
    }

    public struct Card: Decodable, Sendable, Identifiable {
        public let id: String
        public let name: String
        /// The day of the card's last repayment (yyyy-MM-dd), or the start of the month.
        public let since: String
        public let owed: Int
        public let buffered: Int
        public let transactions: Int
    }

    public let pot: BufferPot?
    public let cards: [Card]
    public let owed: Int
    public let buffered: Int
    public let unbuffered: Int
    public let status: Status
    public let shortfall: Int
}

public struct BudgetProgress: Decodable, Sendable, Identifiable {
    public enum Status: String, Decodable, Sendable {
        case ok
        case atRisk = "at_risk"
        case over
    }

    public let id: String
    public let name: String
    public let limit: Int
    public let spent: Int
    public let remaining: Int
    public let ratio: Double
    public let expectedRatio: Double
    public let status: Status
    public let categories: [String]
    public let people: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, limit, spent, remaining, ratio
        case expectedRatio = "expected_ratio"
        case status, categories, people
    }
}

public struct PlanStrip: Decodable, Sendable {
    public let inPots: Int
    public let latestMonth: String?
    public let latestInterest: Int
    public let runRate: Int
    public let twelveMonths: Int
    public let monthsRecorded: Int
    public let taxEstimate: Int
    public let asOf: String

    enum CodingKeys: String, CodingKey {
        case inPots = "in_pots"
        case latestMonth = "latest_month"
        case latestInterest = "latest_interest"
        case runRate = "run_rate"
        case twelveMonths = "twelve_months"
        case monthsRecorded = "months_recorded"
        case taxEstimate = "tax_estimate"
        case asOf = "as_of"
    }
}

public struct PlanPot: Decodable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let balance: Int
    public let goal: Int?
    public let interest: Int
    public let aer: Double?
    public let share: Double
}

public struct InterestMonth: Decodable, Sendable, Identifiable {
    public struct Line: Decodable, Sendable {
        public let pot: String
        public let amount: Int
        public let estimated: Bool
        public let aer: Double
    }

    public var id: String { month }
    /// yyyy-MM
    public let month: String
    public let total: Int
    public let pots: Int
    public let estimated: Bool
    public let lines: [Line]
}

public struct SpendingResponse: Decodable, Sendable {
    public let data: Spending
}

public struct Spending: Decodable, Sendable {
    public let month: String
    public let total: Int
    public let transactions: [SpendingTransaction]
}

public struct SpendingTransaction: Decodable, Sendable, Identifiable {
    public let id: String
    public let time: Date
    /// Positive for spending, negative for a refund.
    public let amount: Int
    public let merchant: String
    public let category: String
    public let accountId: String
    public let account: String
    public let person: String?
    public let source: String
    public let pending: Bool
    public let budgetId: String?
    /// `requested`, `linked` or `failed` once the transaction has been through Add to buffer.
    public let buffer: String?

    /// Only open-banking credit-card spending can go to the buffer, and only once.
    public var canAddToBuffer: Bool {
        source == "gocardless" && amount > 0 && buffer != "requested" && buffer != "linked"
    }

    enum CodingKeys: String, CodingKey {
        case id, time, amount, merchant, category
        case accountId = "account_id"
        case account, person, source, pending
        case budgetId = "budget_id"
        case buffer
    }
}

public struct BufferPreviewResponse: Decodable, Sendable {
    public let data: BufferPreview
}

public struct BufferPreview: Decodable, Sendable {
    public struct Pot: Decodable, Sendable {
        public let id: String
        public let name: String
    }

    public let total: Int
    public let pot: Pot
    public let transactions: [SpendingTransaction]
}

public struct BufferResult: Decodable, Sendable {
    public let data: Outcome

    public struct Outcome: Decodable, Sendable {
        public let total: Int
        public let status: String
    }
}

public struct BufferRequest: Encodable, Sendable {
    public let eventIds: [String]
    public let confirmedTotal: Int?

    public init(eventIds: [String], confirmedTotal: Int? = nil) {
        self.eventIds = eventIds
        self.confirmedTotal = confirmedTotal
    }

    enum CodingKeys: String, CodingKey {
        case eventIds = "event_ids"
        case confirmedTotal = "confirmed_total"
    }
}

public struct CardBufferPotRequest: Encodable, Sendable {
    public let cardBuffer: Bool

    public init(cardBuffer: Bool) {
        self.cardBuffer = cardBuffer
    }

    enum CodingKeys: String, CodingKey {
        case cardBuffer = "card_buffer"
    }
}

public struct CardBufferPotResponse: Decodable, Sendable {
    public struct Outcome: Decodable, Sendable {
        public let cardBufferPotId: String?

        enum CodingKeys: String, CodingKey {
            case cardBufferPotId = "card_buffer_pot_id"
        }
    }

    public let data: Outcome
}
