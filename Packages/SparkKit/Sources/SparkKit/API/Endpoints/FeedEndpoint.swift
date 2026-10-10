import Foundation

public enum FeedEndpoint {
    /// GET /feed — cursor-paginated reverse-chronological event feed.
    /// Pass `domain` to filter by domain (e.g. "knowledge", "money").
    /// Pass `date` as `YYYY-MM-DD` to restrict results to one calendar day.
    /// Pass `usesETag: true` only when the caller persists the pages it reads.
    public static func feed(
        cursor: String? = nil,
        limit: Int = 20,
        domain: String? = nil,
        date: String? = nil,
        usesETag: Bool = false
    ) -> Endpoint<Page<Event>> {
        var query: [URLQueryItem] = []
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        query.append(URLQueryItem(name: "limit", value: String(limit)))
        if let domain {
            query.append(URLQueryItem(name: "domain", value: domain))
        }
        if let date {
            query.append(URLQueryItem(name: "date", value: date))
        }
        return Endpoint(method: .get, path: "/feed", query: query, usesETag: usesETag)
    }
}
