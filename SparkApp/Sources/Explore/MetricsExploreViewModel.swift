import Foundation
import Observation
import OSLog
import SparkKit

@Observable
@MainActor
final class MetricsExploreViewModel {
    enum LoadState { case idle, loading, loaded, error(String) }

    private(set) var snapshots: [String: MetricDetail] = [:]
    private(set) var loadState: LoadState = .idle

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.spark", category: "MetricsExplore")

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load(identifiers: [String]) async {
        guard case .idle = loadState else { return }
        loadState = .loading
        await fetchAll(identifiers: identifiers)
    }

    func refresh(identifiers: [String]) async {
        snapshots = [:]
        loadState = .idle
        await fetchAll(identifiers: identifiers)
    }

    private func fetchAll(identifiers: [String]) async {
        await withTaskGroup(of: (String, MetricDetail?).self) { group in
            let client = apiClient
            for id in identifiers {
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
