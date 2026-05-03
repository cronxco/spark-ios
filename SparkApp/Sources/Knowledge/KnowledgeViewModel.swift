import Foundation
import Observation
import OSLog
import SparkKit

@Observable
@MainActor
final class KnowledgeViewModel {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case newsletters = "Newsletters"
        case webDigests = "Web Digests"
        var id: String { rawValue }
    }

    enum LoadState {
        case idle, loading, loaded, error(String)
    }

    var filter: Filter = .all
    private(set) var allItems: [Event] = []
    private(set) var loadState: LoadState = .idle
    private var cursor: String?
    private(set) var hasMore: Bool = false

    var filteredItems: [Event] {
        switch filter {
        case .all: allItems
        case .newsletters: allItems.filter { $0.service == "newsletter" }
        case .webDigests: allItems.filter { $0.service == "fetch" }
        }
    }

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.spark", category: "Knowledge")

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func initialLoad() async {
        guard case .idle = loadState else { return }
        await fetch(appending: false)
    }

    func refresh() async {
        cursor = nil
        hasMore = false
        allItems = []
        loadState = .idle
        await fetch(appending: false)
    }

    func loadMore() async {
        guard hasMore, case .loaded = loadState else { return }
        await fetch(appending: true)
    }

    private func fetch(appending: Bool) async {
        loadState = .loading
        do {
            let page = try await apiClient.request(
                FeedEndpoint.feed(cursor: appending ? cursor : nil, limit: 30, domain: "knowledge")
            )
            if appending {
                allItems.append(contentsOf: page.data)
            } else {
                allItems = page.data
            }
            cursor = page.nextCursor
            hasMore = page.hasMore
            loadState = .loaded
        } catch APIError.notModified {
            loadState = .loaded
        } catch is CancellationError {
            loadState = allItems.isEmpty ? .idle : .loaded
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Knowledge feed failed: \(String(describing: error))")
            loadState = .error((error as? LocalizedError)?.errorDescription ?? "Couldn't load articles.")
        }
    }
}
