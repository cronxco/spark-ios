import Foundation

public enum FeedEndpoint {
    /// GET /feed — cursor-paginated reverse-chronological event feed.
    public static func feed(cursor: String? = nil, limit: Int = 20) -> Endpoint<Page<Event>> {
        var query: [URLQueryItem] = []
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        query.append(URLQueryItem(name: "limit", value: String(limit)))
        return Endpoint(method: .get, path: "/feed", query: query)
    }
}
