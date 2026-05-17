import Foundation
import Observation
import OSLog
import SparkKit

@Observable
@MainActor
final class MetricsExploreViewModel {
    enum LoadState { case idle, loading, loaded, error(String) }
    enum MetadataState { case idle, loaded(MetricsMetadataSummary), unavailable }

    private(set) var snapshots: [String: MetricDetail] = [:]
    private(set) var metrics: [Metric] = []
    private(set) var loadState: LoadState = .idle
    private(set) var metadataState: MetadataState = .idle

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "MetricsExplore")

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
        metrics = []
        loadState = .idle
        metadataState = .idle
        await fetchAll()
    }

    private func fetchAll() async {
        loadState = .loading
        do {
            let metrics = try await apiClient.request(MetricsEndpoint.list())
            self.metrics = metrics.filter { $0.eventCount > 0 }
            metadataState = .loaded(MetricsMetadataSummary(metrics: self.metrics))
        } catch where error.isAPICancellation {
            loadState = .idle
            return
        } catch {
            logger.error("Metrics list failed: \(String(describing: error), privacy: .public)")
            metrics = []
            metadataState = .unavailable
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            loadState = .error(message)
            return
        }

        snapshots = await fetchDetails(identifiers: metrics.map(\.identifier))
        loadState = .loaded
    }

    private func fetchDetails(identifiers: [String]) async -> [String: MetricDetail] {
        var details: [String: MetricDetail] = [:]
        await withTaskGroup(of: (String, MetricDetail?).self) { group in
            let client = apiClient
            for id in identifiers {
                group.addTask {
                    do {
                        let detail = try await client.request(
                            MetricsEndpoint.detail(identifier: id, range: .thirtyDays)
                        )
                        return (id, detail)
                    } catch {
                        return (id, nil)
                    }
                }
            }
            for await (id, detail) in group {
                if let detail { details[id] = detail }
            }
        }
        return details
    }
}

struct MetricsMetadataSummary: Equatable, Sendable {
    let activeSourceCount: Int
    let lastSyncAt: Date?

    init(metrics: [Metric]) {
        activeSourceCount = metrics.filter { $0.eventCount > 0 }.count
        lastSyncAt = metrics.compactMap(\.lastEventAt).max()
    }
}
