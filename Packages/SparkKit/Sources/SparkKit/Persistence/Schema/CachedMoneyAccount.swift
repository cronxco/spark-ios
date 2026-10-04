import Foundation
import SwiftData

@Model
public final class CachedMoneyAccount {
    @Attribute(.unique) public var id: String
    public var title: String
    public var kind: String
    public var accountType: String?
    public var currency: String
    public var isNegativeBalance: Bool
    public var provider: String?
    public var latestBalance: Double?
    public var latestBalanceTime: Date?
    public var updatedAt: Date
    public var lastSyncedAt: Date

    public init(
        id: String,
        title: String,
        kind: String,
        accountType: String? = nil,
        currency: String,
        isNegativeBalance: Bool,
        provider: String? = nil,
        latestBalance: Double? = nil,
        latestBalanceTime: Date? = nil,
        updatedAt: Date,
        lastSyncedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.accountType = accountType
        self.currency = currency
        self.isNegativeBalance = isNegativeBalance
        self.provider = provider
        self.latestBalance = latestBalance
        self.latestBalanceTime = latestBalanceTime
        self.updatedAt = updatedAt
        self.lastSyncedAt = lastSyncedAt
    }

    public static func upsert(_ account: MoneyAccount, in context: ModelContext) {
        let id = account.id
        let descriptor = FetchDescriptor<CachedMoneyAccount>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.title = account.title
            existing.kind = account.kind
            existing.accountType = account.accountType
            existing.currency = account.currency
            existing.isNegativeBalance = account.isNegativeBalance
            existing.provider = account.provider
            existing.latestBalance = account.latestBalance?.balance
            existing.latestBalanceTime = account.latestBalance?.time
            existing.updatedAt = account.updatedAt
            existing.lastSyncedAt = .now
        } else {
            context.insert(CachedMoneyAccount(
                id: account.id,
                title: account.title,
                kind: account.kind,
                accountType: account.accountType,
                currency: account.currency,
                isNegativeBalance: account.isNegativeBalance,
                provider: account.provider,
                latestBalance: account.latestBalance?.balance,
                latestBalanceTime: account.latestBalance?.time,
                updatedAt: account.updatedAt
            ))
        }
    }
}
