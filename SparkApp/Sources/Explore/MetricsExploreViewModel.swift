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
        metrics = []
        loadState = .idle
        metadataState = .idle
        await fetchAll(identifiers: identifiers)
    }

    private func fetchAll(identifiers: [String]) async {
        do {
            let metrics = try await apiClient.request(MetricsEndpoint.list())
            self.metrics = metrics
            metadataState = .loaded(MetricsMetadataSummary(metrics: metrics))
        } catch {
            logger.error("Metrics list failed: \(String(describing: error), privacy: .public)")
            metrics = []
            metadataState = .unavailable
        }

        snapshots = await fetchDetails(identifiers: identifiers)
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
                            MetricsEndpoint.detail(identifier: id, range: .sevenDays)
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
