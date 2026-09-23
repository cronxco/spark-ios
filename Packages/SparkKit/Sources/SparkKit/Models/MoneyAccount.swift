import Foundation

public struct MoneyAccount: Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let kind: String
    public let accountType: String?
    public let currency: String
    public let isNegativeBalance: Bool
    public let provider: String?
    public let accountNumber: String?
    public let sortCode: String?
    public let interestRate: Double?
    public let startDate: String?
    public let integrationId: String?
    /// `nil` from a server that predates the flag. Read `pinned`.
    public let isPinned: Bool?
    public let latestBalance: BalanceEntry?
    public let updatedAt: Date

    /// The account the user chose to see first. At most one per user, and any
    /// account type can be it — not just manual ones.
    public var pinned: Bool { isPinned ?? false }

    public init(
        id: String, title: String, kind: String, accountType: String?,
        currency: String, isNegativeBalance: Bool, provider: String?,
        accountNumber: String?, sortCode: String?, interestRate: Double?,
        startDate: String?, integrationId: String?, isPinned: Bool? = nil,
        latestBalance: BalanceEntry?, updatedAt: Date
    ) {
        self.id = id; self.title = title; self.kind = kind
        self.accountType = accountType; self.currency = currency
        self.isNegativeBalance = isNegativeBalance; self.provider = provider
        self.accountNumber = accountNumber; self.sortCode = sortCode
        self.interestRate = interestRate; self.startDate = startDate
        self.integrationId = integrationId; self.isPinned = isPinned
        self.latestBalance = latestBalance
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, kind, currency, provider
        case accountType = "account_type"
        case isNegativeBalance = "is_negative_balance"
        case accountNumber = "account_number"
        case sortCode = "sort_code"
        case interestRate = "interest_rate"
        case startDate = "start_date"
        case integrationId = "integration_id"
        case isPinned = "is_pinned"
        case latestBalance = "latest_balance"
        case updatedAt = "updated_at"
    }
}

public struct BalanceEntry: Codable, Sendable, Identifiable {
    public let id: String
    public let balance: Double
    public let currency: String
    public let time: Date
    public let notes: String?
}

public struct MoneyAccountsResponse: Codable, Sendable, CursorPaged {
    public let data: [MoneyAccount]
    public let nextCursor: String?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        data = try c.decode([MoneyAccount].self, forKey: .data)
        nextCursor = try c.decodeIfPresent(String.self, forKey: .nextCursor)
        hasMore = try c.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }
}

/// `GET /money/net-worth` — the total, and how it compares with the start of
/// a window. One request where the client used to fetch every account and
/// then every account's balance history to show two numbers.
public struct NetWorth: Codable, Sendable, Hashable {
    public struct Comparison: Codable, Sendable, Hashable {
        public let window: String
        public let then: Double
        public let change: Double
        /// `nil` when the starting figure was zero.
        public let changePct: Double?

        enum CodingKeys: String, CodingKey {
            case window, then, change
            case changePct = "change_pct"
        }
    }

    public let total: Double
    public let currency: String
    public let comparison: Comparison?
    /// Accounts left out of the comparison — a different currency, or a
    /// history that does not span the window. Still counted in `total`.
    public let excludedAccounts: Int
    public let asOf: Date?

    enum CodingKeys: String, CodingKey {
        case total, currency, comparison
        case excludedAccounts = "excluded_accounts"
        case asOf = "as_of"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total = try c.decode(Double.self, forKey: .total)
        currency = try c.decode(String.self, forKey: .currency)
        comparison = try c.decodeIfPresent(Comparison.self, forKey: .comparison)
        excludedAccounts = try c.decodeIfPresent(Int.self, forKey: .excludedAccounts) ?? 0
        asOf = try c.decodeIfPresent(Date.self, forKey: .asOf)
    }
}

public struct NetWorthResponse: Codable, Sendable {
    public let data: NetWorth
}

public enum NetWorthWindow: String, Sendable, CaseIterable {
    case oneWeek = "1week"
    case oneMonth = "1month"
    case threeMonths = "3months"
    case sixMonths = "6months"
    case oneYear = "1year"
}

public struct MoneyAccountResponse: Codable, Sendable {
    public let data: MoneyAccount
}

public struct BalanceEntryResponse: Codable, Sendable {
    public let data: BalanceEntry
}

public struct CreateAccountRequest: Encodable, Sendable {
    public let name: String
    public let accountType: String
    public let currency: String
    public let provider: String?
    public let accountNumber: String?
    public let sortCode: String?
    public let interestRate: Double?
    public let startDate: String?
    public let isNegativeBalance: Bool

    public init(
        name: String,
        accountType: String,
        currency: String,
        provider: String? = nil,
        accountNumber: String? = nil,
        sortCode: String? = nil,
        interestRate: Double? = nil,
        startDate: String? = nil,
        isNegativeBalance: Bool = false
    ) {
        self.name = name
        self.accountType = accountType
        self.currency = currency
        self.provider = provider
        self.accountNumber = accountNumber
        self.sortCode = sortCode
        self.interestRate = interestRate
        self.startDate = startDate
        self.isNegativeBalance = isNegativeBalance
        self.isPinned = isPinned
    }

    enum CodingKeys: String, CodingKey {
        case name
        case accountType = "account_type"
        case currency
        case provider
        case accountNumber = "account_number"
        case sortCode = "sort_code"
        case interestRate = "interest_rate"
        case startDate = "start_date"
        case isNegativeBalance = "is_negative_balance"
    }
}

public struct UpdateAccountRequest: Encodable, Sendable {
    public let name: String?
    public let accountType: String?
    public let currency: String?
    public let provider: String?
    public let accountNumber: String?
    public let sortCode: String?
    public let interestRate: Double?
    public let startDate: String?
    public let isNegativeBalance: Bool?
    /// Pinning is the one field settable on any account type, not just manual.
    public let isPinned: Bool?

    public init(
        name: String? = nil,
        accountType: String? = nil,
        currency: String? = nil,
        provider: String? = nil,
        accountNumber: String? = nil,
        sortCode: String? = nil,
        interestRate: Double? = nil,
        startDate: String? = nil,
        isNegativeBalance: Bool? = nil,
        isPinned: Bool? = nil
    ) {
        self.name = name
        self.accountType = accountType
        self.currency = currency
        self.provider = provider
        self.accountNumber = accountNumber
        self.sortCode = sortCode
        self.interestRate = interestRate
        self.startDate = startDate
        self.isNegativeBalance = isNegativeBalance
    }

    enum CodingKeys: String, CodingKey {
        case name
        case accountType = "account_type"
        case currency
        case provider
        case accountNumber = "account_number"
        case sortCode = "sort_code"
        case interestRate = "interest_rate"
        case startDate = "start_date"
        case isNegativeBalance = "is_negative_balance"
        case isPinned = "is_pinned"
    }
}

public struct MessageResponse: Decodable, Sendable {
    public let message: String
}

public struct AddBalanceRequest: Encodable, Sendable {
    public let balance: Double
    public let date: String
    public let notes: String?

    public init(balance: Double, date: String, notes: String? = nil) {
        self.balance = balance
        self.date = date
        self.notes = notes
    }
}
