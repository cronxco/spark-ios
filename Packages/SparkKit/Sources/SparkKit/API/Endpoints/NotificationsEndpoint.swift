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
    public static func markRead(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .post, path: "/notifications/\(id)/read")
    }

    /// POST /notifications/read-all
    public static func markAllRead() -> Endpoint<EmptyResponse> {
        Endpoint(method: .post, path: "/notifications/read-all")
    }

    /// DELETE /notifications/{id}
    public static func delete(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .delete, path: "/notifications/\(id)")
    }
}
