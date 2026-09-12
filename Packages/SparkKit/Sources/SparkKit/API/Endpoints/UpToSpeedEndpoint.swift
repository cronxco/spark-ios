import Foundation

public enum UpToSpeedEndpoint {
    private static let encoder = JSONEncoder()

    /// GET /up-to-speed — the ordered catch-up queue.
    ///
    /// Returns read *and* unread items: read state is reported, never enforced,
    /// so the client can both build the unread flow and offer a recap of what
    /// has already been seen. Filter on `caughtUpAt`.
    ///
    /// - Parameters:
    ///   - includeAcknowledged: also return anomalies that have been dismissed.
    ///     Off by default; ask for them when building the recap, since a
    ///     dismissed anomaly is otherwise unrecoverable.
    ///   - newsLimit: cap on news items. The server applies its own default.
    public static func feed(
        includeAcknowledged: Bool = false,
        newsLimit: Int? = nil
    ) -> Endpoint<UpToSpeedResponse> {
        var query: [URLQueryItem] = []
        if includeAcknowledged {
            query.append(URLQueryItem(name: "include_acknowledged", value: "1"))
        }
        if let newsLimit {
            query.append(URLQueryItem(name: "news_limit", value: String(newsLimit)))
        }
        return Endpoint(method: .get, path: "/up-to-speed", query: query)
    }

    /// POST /up-to-speed/read — mark flint_digest, anomaly, and news_summary items as caught up.
    /// Check-in items must NOT be included; completion via CheckInsEndpoint.submit is the read signal.
    public static func markRead(_ refs: [UpToSpeedReadRef]) -> Endpoint<UpToSpeedMarkReadResponse> {
        let body = try? encoder.encode(ItemsBody(items: refs))
        return Endpoint(method: .post, path: "/up-to-speed/read", body: body, contentType: "application/json")
    }

    /// POST /up-to-speed/unmark — return items to the unread queue.
    ///
    /// The recovery path for something dismissed by accident. For an anomaly
    /// this also clears its acknowledgement, which is what actually evicts one
    /// from the feed.
    public static func unmark(_ refs: [UpToSpeedReadRef]) -> Endpoint<UpToSpeedUnmarkResponse> {
        let body = try? encoder.encode(ItemsBody(items: refs))
        return Endpoint(method: .post, path: "/up-to-speed/unmark", body: body, contentType: "application/json")
    }

    private struct ItemsBody: Encodable {
        let items: [UpToSpeedReadRef]
    }
}
