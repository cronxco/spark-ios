import Foundation
import Observation
import OSLog
import SparkKit

@MainActor
@Observable
final class SearchViewModel {
    enum State: Sendable {
        case idle
        case searching
        case results([SearchResult])
        case error(String)
    }

    var query: String = "" {
        didSet { handleQueryChange(oldQuery: oldValue) }
    }
    var mode: SearchEndpoint.Mode = .default

    private(set) var state: State = .idle
    /// How the server served the results on screen. `degraded` means it fell
    /// back to keyword matching, which the UI says.
    private(set) var execution: SearchExecution?
    /// True when the results on screen are from an earlier identical search
    /// because the device is offline.
    private(set) var isShowingCachedResults = false

    /// The request the screen is showing or last tried, so Retry reissues it.
    private var lastRequest: Request?
    private var cache: [Request: SearchResponse] = [:]
    private var cacheOrder: [Request] = []
    private static let cacheLimit = 20

    private struct Request: Hashable {
        let text: String
        let mode: SearchEndpoint.Mode
    }

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "Search")
    private var pendingQuery: Task<Void, Never>?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Group results by their section label, preserving server order.
    var grouped: [(String, [SearchResult])] {
        guard case .results(let items) = state else { return [] }
        var order: [String] = []
        var byLabel: [String: [SearchResult]] = [:]
        for item in items {
            let label = item.sectionLabel
            if byLabel[label] == nil { order.append(label) }
            byLabel[label, default: []].append(item)
        }
        return order.map { ($0, byLabel[$0] ?? []) }
    }

    private func handleQueryChange(oldQuery: String) {
        // Detect prefix shortcuts and translate to a `Mode` change.
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        // Switching mode must still run the search: returning here meant a
        // prefixed query like `#travel` changed the pill but never searched.
        if let first = trimmed.first,
           let candidate = SearchEndpoint.Mode.allCases.first(where: { $0.symbol == String(first) }),
           mode != candidate {
            mode = candidate
        }
        scheduleSearch()
    }

    func setMode(_ new: SearchEndpoint.Mode) {
        mode = new
        scheduleSearch()
    }

    func clear() {
        query = ""
        state = .idle
        execution = nil
        isShowingCachedResults = false
    }

    /// Reissue the request that failed, without the typing debounce.
    func retry() {
        guard let request = lastRequest else { return }
        pendingQuery?.cancel()
        pendingQuery = Task { [weak self] in
            await self?.perform(request)
        }
    }

    private func scheduleSearch() {
        pendingQuery?.cancel()
        let cleanedQuery = stripPrefix(query)
        guard !cleanedQuery.isEmpty else {
            state = .idle
            execution = nil
            isShowingCachedResults = false
            return
        }
        let request = Request(text: cleanedQuery, mode: mode)
        pendingQuery = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.perform(request)
        }
    }

    private func perform(_ request: Request) async {
        lastRequest = request
        state = .searching
        isShowingCachedResults = false
        do {
            let response = try await apiClient.request(SearchEndpoint.query(text: request.text, mode: request.mode))
            guard !Task.isCancelled else { return }
            if !response.droppedKinds.isEmpty {
                SparkObservability.captureSearchDroppedKinds(response.droppedKinds)
            }
            remember(response, for: request)
            execution = response.execution
            state = .results(response.results)
        } catch is CancellationError {
            return
        } catch {
            guard !error.isAPICancellation else { return }
            if error.isConnectivityFailure, let cached = cache[request] {
                execution = cached.execution
                isShowingCachedResults = true
                state = .results(cached.results)
                return
            }
            SparkObservability.captureHandled(error)
            logger.error("Search failed: \(String(describing: error))")
            execution = nil
            state = .error(error.isConnectivityFailure ? "You're offline." : "Couldn't search.")
        }
    }

    private func remember(_ response: SearchResponse, for request: Request) {
        cache[request] = response
        cacheOrder.removeAll { $0 == request }
        cacheOrder.append(request)
        while cacheOrder.count > Self.cacheLimit {
            cache.removeValue(forKey: cacheOrder.removeFirst())
        }
    }

    private func stripPrefix(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "" }
        for candidate in SearchEndpoint.Mode.allCases {
            if let symbol = candidate.symbol, String(first) == symbol {
                return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
        }
        return trimmed
    }
}
