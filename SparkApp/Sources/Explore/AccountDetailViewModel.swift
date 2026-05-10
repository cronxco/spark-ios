import Foundation
import Observation
import OSLog
import SparkKit

@Observable
@MainActor
final class AccountDetailViewModel {
    enum LoadState { case loading, loaded, error(String) }

    private(set) var account: MoneyAccount?
    private(set) var balances: [BalanceEntry] = []
    private(set) var nextCursor: String?
    private(set) var hasMore = false
    private(set) var loadState: LoadState = .loading
    private(set) var isLoadingMore = false
    private(set) var isArchiving = false

    let accountId: String
    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "AccountDetail")

    init(accountId: String, apiClient: APIClient) {
        self.accountId = accountId
        self.apiClient = apiClient
    }

    func load() async {
        loadState = .loading
        async let accountResult = apiClient.request(MoneyEndpoint.account(id: accountId))
        async let balancesResult = apiClient.request(MoneyEndpoint.balances(accountId: accountId))

        do {
            let (accountData, balancesData) = try await (accountResult, balancesResult)
            account = accountData.data
            balances = balancesData.data
            nextCursor = balancesData.nextCursor
            hasMore = balancesData.hasMore
            loadState = .loaded
        } catch where error.isAPICancellation {
            loadState = .loading
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("AccountDetail load failed: \(String(describing: error))")
            loadState = .error((error as? LocalizedError)?.errorDescription ?? "Couldn't load account.")
        }
    }

    func loadMoreBalances() async {
        guard hasMore, let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await apiClient.request(MoneyEndpoint.balances(accountId: accountId, cursor: cursor))
            balances.append(contentsOf: page.data)
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
            logger.error("AccountDetail load more failed: \(String(describing: error))")
        }
    }

    func archive() async throws {
        isArchiving = true
        defer { isArchiving = false }
        _ = try await apiClient.request(MoneyEndpoint.deleteAccount(id: accountId))
    }

    func balanceAdded(_ entry: BalanceEntry) {
        balances.insert(entry, at: 0)
        if var updated = account {
            updated = MoneyAccount(
                id: updated.id,
                title: updated.title,
                kind: updated.kind,
                accountType: updated.accountType,
                currency: updated.currency,
                isNegativeBalance: updated.isNegativeBalance,
                provider: updated.provider,
                accountNumber: updated.accountNumber,
                sortCode: updated.sortCode,
                interestRate: updated.interestRate,
                startDate: updated.startDate,
                integrationId: updated.integrationId,
                latestBalance: entry,
                updatedAt: updated.updatedAt
            )
            account = updated
        }
    }

    func accountUpdated(_ updated: MoneyAccount) {
        account = updated
    }
}
