import Foundation

public enum BriefingEndpoint {
    /// GET /briefing/today?date=YYYY-MM-DD
    public static func today(date: String? = nil, domains: [String]? = nil) -> Endpoint<DaySummary> {
        var query: [URLQueryItem] = []
        if let date {
            query.append(URLQueryItem(name: "date", value: date))
        }
        if let domains, !domains.isEmpty {
            query.append(URLQueryItem(name: "domains", value: domains.joined(separator: ",")))
        }
        return Endpoint(method: .get, path: "/briefing/today", query: query)
    }
}
