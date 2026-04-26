import Foundation

public enum SearchEndpoint {
    public enum Mode: String, Sendable, CaseIterable {
        case `default`
        case actions
        case tags
        case metrics
        case integrations
        case semantic

        /// Single-character prefix used in the web Spotlight (`>` etc.). The
        /// search bar swallows the prefix and switches `Mode`.
        public var symbol: String? {
            switch self {
            case .default: nil
            case .actions: ">"
            case .tags: "#"
            case .metrics: "$"
            case .integrations: "@"
            case .semantic: "~"
            }
        }

        public var label: String {
            switch self {
            case .default: "All"
            case .actions: "Actions"
            case .tags: "Tags"
            case .metrics: "Metrics"
            case .integrations: "Integrations"
            case .semantic: "Semantic"
            }
        }
    }

    /// GET /search?q=…&mode=…
    public static func query(text: String, mode: Mode = .default) -> Endpoint<[SearchResult]> {
        Endpoint(
            method: .get,
            path: "/search",
            query: [
                URLQueryItem(name: "q", value: text),
                URLQueryItem(name: "mode", value: mode.rawValue),
            ]
        )
    }
}
