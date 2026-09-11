import Foundation

public enum NotificationsEndpoint {
    public enum Scope: String, Sendable, Hashable { case active, history }

    /// GET /notifications?cursor=…
    public static func list(cursor: String? = nil) -> Endpoint<Page<NotificationItem>> {
        var query: [URLQueryItem] = []
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(method: .get, path: "/notifications", query: query)
    }

    /// GET /notifications/feed — the shared web/iOS feed contract.
    public static func feed(
        scope: Scope = .active,
        stream: NotificationFeedItem.Stream? = nil,
        search: String? = nil,
        cursor: String? = nil,
        limit: Int = 25
    ) -> Endpoint<NotificationFeedPage> {
        var query = [
            URLQueryItem(name: "scope", value: scope.rawValue),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let stream { query.append(URLQueryItem(name: "stream", value: stream.rawValue)) }
        if let search, !search.isEmpty { query.append(URLQueryItem(name: "search", value: search)) }
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        return Endpoint(method: .get, path: "/notifications/feed", query: query)
    }

    /// POST /notifications/{id}/read
    ///
    /// Idempotent, so the server requires no precondition.
    public static func markRead(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .post, path: "/notifications/\(id)/read")
    }

    /// POST /notifications/{id}/unread
    public static func markUnread(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .post, path: "/notifications/\(id)/unread")
    }

    /// POST /notifications/{id}/archive
    ///
    /// Archiving is reversible from History, so it is an idempotent state
    /// transition and intentionally carries no precondition.
    public static func archive(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .post, path: "/notifications/\(id)/archive")
    }

    /// POST /notifications/read-all
    ///
    /// Idempotent, so the server requires no precondition.
    public static func markAllRead() -> Endpoint<EmptyResponse> {
        Endpoint(method: .post, path: "/notifications/read-all")
    }

    /// DELETE /notifications/{id}
    ///
    /// Destructive, so the server requires `If-Match` and answers `428`
    /// without one. Pass the `version` from the item in `GET /notifications`.
    public static func delete(id: String, version: String?) -> Endpoint<EmptyResponse> {
        Endpoint(method: .delete, path: "/notifications/\(id)").withIfMatch(version)
    }
}
