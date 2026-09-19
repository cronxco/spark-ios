import Foundation
import Observation
import OSLog
import SparkKit

@Observable
@MainActor
final class HealthExploreViewModel {
    typealias DashboardRange = HealthEndpoint.DashboardRange

    enum LoadState {
        case idle
        case loading
        case loaded
        case error(String)
    }

    private(set) var dashboard: HealthDashboard?

    private(set) var loadState: LoadState = .idle
    var selectedRange: DashboardRange = .sevenDays

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "HealthExplore")

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        guard case .idle = loadState else { return }
        await fetchDashboard()
    }

    func refresh() async {
        await fetchDashboard()
    }

    func selectRange(_ range: DashboardRange) async {
        guard selectedRange != range else { return }
        selectedRange = range
        await fetchDashboard()
    }

    private func fetchDashboard() async {
        loadState = .loading

        do {
                            dashboard = try await apiClient.request(
                    HealthEndpoint.dashboard(date: "today", range: selectedRange)
                )

            loadState = .loaded
        } catch where error.isAPICancellation {
            loadState = dashboard == nil ? .idle : .loaded
        } catch {
            logger.error("Health dashboard failed: \(String(describing: error), privacy: .public)")
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            loadState = .error(message)
        }
    }
}
