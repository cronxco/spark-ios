import Foundation

public enum UpToSpeedEndpoint {
    private static let encoder = JSONEncoder()

    /// GET /up-to-speed — ordered catch-up queue (read + unread; filter by caughtUpAt client-side).
    public static func feed(date: String? = nil) -> Endpoint<UpToSpeedResponse> {
        var query: [URLQueryItem] = []
        if let date {
            query.append(URLQueryItem(name: "date", value: date))
        }
        return Endpoint(method: .get, path: "/up-to-speed", query: query)
    }

    /// POST /up-to-speed/read — mark flint_digest, anomaly, and news_summary items as caught up.
    /// Check-in items must NOT be included; completion via CheckInsEndpoint.submit is the read signal.
    public static func markRead(_ refs: [UpToSpeedReadRef]) -> Endpoint<UpToSpeedMarkReadResponse> {
        let body = try? encoder.encode(MarkReadBody(items: refs))
        return Endpoint(method: .post, path: "/up-to-speed/read", body: body, contentType: "application/json")
    }

    private struct MarkReadBody: Encodable {
        let items: [UpToSpeedReadRef]
    }
}
