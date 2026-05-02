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

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.spark", category: "Search")
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
        if let first = trimmed.first {
            for candidate in SearchEndpoint.Mode.allCases {
                if let symbol = candidate.symbol, String(first) == symbol {
                    if mode != candidate { mode = candidate }
                    return
                }
            }
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
    }

    private func scheduleSearch() {
        pendingQuery?.cancel()
        let cleanedQuery = stripPrefix(query)
        guard !cleanedQuery.isEmpty else {
            state = .idle
            return
        }
        pendingQuery = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.performSearch(text: cleanedQuery)
        }
    }

    private func performSearch(text: String) async {
        state = .searching
        do {
            let results = try await apiClient.request(SearchEndpoint.query(text: text, mode: mode))
            state = .results(results)
        } catch is CancellationError {
            return
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Search failed: \(String(describing: error))")
            state = .error("Couldn't search.")
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
