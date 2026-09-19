import Foundation

public enum FlintTopicsEndpoint {
    /// GET /flint/topics?status=active&kind=thematic
    /// Flint's long-lived threads. Both filters are optional.
    public static func list(status: FlintTopicStatus? = nil, kind: FlintTopicKind? = nil) -> Endpoint<FlintTopicsResponse> {
        var query: [URLQueryItem] = []
        if let status {
            query.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if let kind {
            query.append(URLQueryItem(name: "kind", value: kind.rawValue))
        }
        return Endpoint(method: .get, path: "/flint/topics", query: query)
    }

    /// GET /flint/topics/{id}, including versioned linked evidence.
    public static func detail(id: String) -> Endpoint<FlintTopicResponse> {
        Endpoint(method: .get, path: "/flint/topics/\(id)")
    }
}
