import Foundation
import Observation
import OSLog
import SparkKit

@Observable
@MainActor
final class HealthExploreViewModel {
    private static let identifiers: [String] = [
        "oura.sleep_score",
        "oura.heart_rate",
        "oura.hrv",
        "oura.steps",
        "oura.calories",
    ]

    enum LoadState { case idle, loading, loaded, error(String) }

    private(set) var snapshots: [String: MetricDetail] = [:]
    private(set) var loadState: LoadState = .idle

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.spark", category: "HealthExplore")

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        guard case .idle = loadState else { return }
        loadState = .loading
        await fetchAll()
    }

    func refresh() async {
        snapshots = [:]
        loadState = .idle
        await fetchAll()
    }

    private func fetchAll() async {
        await withTaskGroup(of: (String, MetricDetail?).self) { group in
            let client = apiClient
            for id in Self.identifiers {
                group.addTask {
                    do {
                        let detail = try await client.request(
                            MetricsEndpoint.detail(identifier: id, range: .sevenDays)
                        )
                        return (id, detail)
                    } catch {
                        return (id, nil)
                    }
                }
            }
            for await (id, detail) in group {
                if let detail { snapshots[id] = detail }
            }
        }
        loadState = .loaded
    }
}
