import Foundation

public enum SearchEndpoint {
    /// The search contract version this build speaks. The server serves the
    /// versioned envelope only when asked for it; see `SearchResponse`.
    public static let contractVersion = 1

    public enum EntityType: String, Sendable, CaseIterable {
        case events, objects, blocks
    }
    /// Search modes the backend serves. There is no Actions mode yet: the
    /// server rejects `mode=actions` with 422, so it is not offered until an
    /// action registry exists behind it.
    public enum Mode: String, Sendable, CaseIterable {
        case `default`
        case tags
        case metrics
        case integrations
        case semantic

        /// The backend's singular mode name (`tag`, `metric`, `integration`).
        public var queryValue: String {
            switch self {
            case .tags: "tag"
            case .metrics: "metric"
            case .integrations: "integration"
            default: rawValue
            }
        }

        /// Single-character prefix used in the web Spotlight (`>` etc.). The
        /// search bar swallows the prefix and switches `Mode`.
        public var symbol: String? {
            switch self {
            case .default: nil
            case .tags: "#"
            case .metrics: "$"
            case .integrations: "@"
            case .semantic: "~"
            }
        }

        public var label: String {
            switch self {
            case .default: "All"
            case .tags: "Tags"
            case .metrics: "Metrics"
            case .integrations: "Integrations"
            case .semantic: "Semantic"
            }
        }
    }

    /// GET /search?contract_version=1&query=…&mode=…
    ///
    /// Needs a backend that serves contract v1: older ones read `q` and would
    /// return nothing for `query`.
    public static func query(text: String, mode: Mode = .default, limit: Int? = nil) -> Endpoint<SearchResponse> {
        var items = [
            URLQueryItem(name: "contract_version", value: String(contractVersion)),
            URLQueryItem(name: "query", value: text),
            URLQueryItem(name: "mode", value: mode.queryValue),
        ]
        if let limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        return Endpoint(method: .get, path: "/search", query: items)
    }

    /// Typed entity search used by relationship selection and DEBUG tools.
    /// The backend requires `query` and a `boolean` `semantic` ("1"/"0").
    public static func entity(_ type: EntityType, query: String, semantic: Bool = false) -> Endpoint<SearchResponse> {
        Endpoint(
            method: .get,
            path: "/search/\(type.rawValue)",
            query: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "semantic", value: semantic ? "1" : "0"),
            ]
        )
    }
}
