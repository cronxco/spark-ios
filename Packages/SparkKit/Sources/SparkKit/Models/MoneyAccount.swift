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
    public let latestBalance: BalanceEntry?
    public let updatedAt: Date

    public init(
        id: String, title: String, kind: String, accountType: String?,
        currency: String, isNegativeBalance: Bool, provider: String?,
        accountNumber: String?, sortCode: String?, interestRate: Double?,
        startDate: String?, integrationId: String?,
        latestBalance: BalanceEntry?, updatedAt: Date
    ) {
        self.id = id; self.title = title; self.kind = kind
        self.accountType = accountType; self.currency = currency
        self.isNegativeBalance = isNegativeBalance; self.provider = provider
        self.accountNumber = accountNumber; self.sortCode = sortCode
        self.interestRate = interestRate; self.startDate = startDate
        self.integrationId = integrationId; self.latestBalance = latestBalance
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

public struct MoneyAccountsResponse: Codable, Sendable {
    public let data: [MoneyAccount]
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

    public init(
        name: String? = nil,
        accountType: String? = nil,
        currency: String? = nil,
        provider: String? = nil,
        accountNumber: String? = nil,
        sortCode: String? = nil,
        interestRate: Double? = nil,
        startDate: String? = nil,
        isNegativeBalance: Bool? = nil
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
