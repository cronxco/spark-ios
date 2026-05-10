import Foundation
import Observation
import OSLog
import SparkKit

@Observable
@MainActor
final class MoneyExploreViewModel {
    enum LoadState { case idle, loading, loaded, error(String) }

    private(set) var spend: SpendWidget?
    private(set) var transactions: [Event] = []
    private(set) var accounts: [MoneyAccount] = []
    private(set) var loadState: LoadState = .idle
    private(set) var accountsState: LoadState = .idle

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "MoneyExplore")

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        guard case .idle = loadState else { return }
        loadState = .loading
        accountsState = .loading
        await fetchAll()
    }

    func refresh() async {
        spend = nil
        transactions = []
        accounts = []
        loadState = .idle
        accountsState = .idle
        await fetchAll()
    }

    func accountCreated(_ account: MoneyAccount) {
        accounts.append(account)
    }

    private func fetchAll() async {
        async let spendResult = apiClient.request(WidgetsEndpoint.spend())
        async let feedResult = apiClient.request(FeedEndpoint.feed(limit: 30, domain: "money"))
        async let accountsResult = apiClient.request(MoneyEndpoint.accounts())

        do {
            let (spendData, feedData) = try await (spendResult, feedResult)
            spend = spendData
            transactions = feedData.data.filter { !$0.hidden }
            loadState = .loaded
        } catch where error.isAPICancellation {
            loadState = .idle
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Money explore spend/feed failed: \(String(describing: error))")
            loadState = .error((error as? LocalizedError)?.errorDescription ?? "Couldn't load money data.")
        }

        do {
            let accountsData = try await accountsResult
            accounts = accountsData.data
            accountsState = .loaded
        } catch where error.isAPICancellation {
            accountsState = .idle
        } catch {
            logger.error("Money explore accounts failed: \(String(describing: error))")
            accountsState = .error("Couldn't load accounts.")
        }
    }
}
