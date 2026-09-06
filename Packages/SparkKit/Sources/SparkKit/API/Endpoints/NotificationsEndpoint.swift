import Foundation

public enum NotificationsEndpoint {
    /// GET /notifications?cursor=…
    public static func list(cursor: String? = nil) -> Endpoint<Page<NotificationItem>> {
        var query: [URLQueryItem] = []
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(method: .get, path: "/notifications", query: query)
    }

    /// POST /notifications/{id}/read
    ///
    /// Idempotent, so the server requires no precondition.
    public static func markRead(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .post, path: "/notifications/\(id)/read")
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
