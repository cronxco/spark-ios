import Foundation

public enum PeopleEndpoint {
    /// GET /people/{id}/timeline
    ///
    /// `month` (`yyyy-MM`) picks the calendar grid; `date` (`yyyy-MM-dd`) lists
    /// that day's events instead of the latest ones.
    public static func timeline(id: String, month: String? = nil, date: String? = nil) -> Endpoint<PersonTimeline> {
        var query = [URLQueryItem]()
        if let month { query.append(URLQueryItem(name: "month", value: month)) }
        if let date { query.append(URLQueryItem(name: "date", value: date)) }
        return Endpoint(method: .get, path: "/people/\(id)/timeline", query: query)
    }
}
