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
    private(set) var rawFeedEntries: [RawFeedJSONEntry] = []
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
        rawFeedEntries = []
        loadState = .idle
        metadataState = .idle
        await fetchAll()
    }

    private func fetchAll() async {
        loadState = .loading
        do {
            let response = try await apiClient.requestWithRawResponse(MetricsEndpoint.list())
            self.metrics = response.decoded.filter { $0.eventCount > 0 }
            #if DEBUG
                rawFeedEntries = [
                    RawFeedJSONEntry(title: "GET /metrics", body: response.utf8Body)
                ]
            #endif
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

        let details = await fetchDetails(identifiers: metrics.map(\.identifier))
        snapshots = details.snapshots
        #if DEBUG
            rawFeedEntries.append(contentsOf: details.rawEntries)
        #endif
        loadState = .loaded
    }

    private func fetchDetails(identifiers: [String]) async -> (snapshots: [String: MetricDetail], rawEntries: [RawFeedJSONEntry]) {
        var details: [String: MetricDetail] = [:]
        var rawEntries: [RawFeedJSONEntry] = []
        await withTaskGroup(of: (String, MetricDetail?, String?).self) { group in
            let client = apiClient
            for id in identifiers {
                group.addTask {
                    do {
                        let response = try await client.requestWithRawResponse(
                            MetricsEndpoint.detail(identifier: id, range: .thirtyDays)
                        )
                        return (id, response.decoded, response.utf8Body)
                    } catch {
                        return (id, nil, nil)
                    }
                }
            }
            for await (id, detail, rawBody) in group {
                if let detail { details[id] = detail }
                if let rawBody {
                    rawEntries.append(RawFeedJSONEntry(title: "GET /metrics/\(MetricsEndpoint.canonicalIdentifier(id))?range=30d", body: rawBody))
                }
            }
        }
        rawEntries.sort { $0.title < $1.title }
        return (details, rawEntries)
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
