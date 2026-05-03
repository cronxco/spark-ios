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
    private(set) var loadState: LoadState = .idle

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.spark", category: "MoneyExplore")

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        guard case .idle = loadState else { return }
        loadState = .loading
        await fetchAll()
    }

    func refresh() async {
        spend = nil
        transactions = []
        loadState = .idle
        await fetchAll()
    }

    private func fetchAll() async {
        async let spendResult = apiClient.request(WidgetsEndpoint.spend())
        async let feedResult = apiClient.request(FeedEndpoint.feed(limit: 30, domain: "money"))

        do {
            let (spendData, feedData) = try await (spendResult, feedResult)
            spend = spendData
            transactions = feedData.data
            loadState = .loaded
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Money explore failed: \(String(describing: error))")
            loadState = .error((error as? LocalizedError)?.errorDescription ?? "Couldn't load money data.")
        }
    }
}
