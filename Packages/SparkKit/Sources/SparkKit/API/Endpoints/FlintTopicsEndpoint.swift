import Foundation

public enum FlintTopicsEndpoint {
    /// GET /flint/topics?status=active&kind=thematic
    /// Flint's long-lived threads. Both filters are optional. Cursor-paged;
    /// use `APIClient.collectAllPages` for the whole list.
    public static func list(
        status: FlintTopicStatus? = nil,
        kind: FlintTopicKind? = nil,
        limit: Int? = nil,
        cursor: String? = nil
    ) -> Endpoint<FlintTopicsResponse> {
        var query: [URLQueryItem] = []
        if let status {
            query.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if let kind {
            query.append(URLQueryItem(name: "kind", value: kind.rawValue))
        }
        if let limit {
            query.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(method: .get, path: "/flint/topics", query: query)
    }

    /// GET /flint/topics/{id}, including versioned linked evidence.
    public static func detail(id: String) -> Endpoint<FlintTopicResponse> {
        Endpoint(method: .get, path: "/flint/topics/\(id)")
    }

    public static func changeKind(id: String, kind: FlintTopicKind, etag: String) -> Endpoint<FlintTopicResponse> {
        Endpoint(
            method: .patch, path: "/flint/topics/\(id)",
            body: try? JSONEncoder().encode(["kind": kind.rawValue]),
            contentType: "application/json",
            headers: ["If-Match": etag]
        )
    }

    public static func createTask(id: String, request: FlintTopicTaskRequest, etag: String) -> Endpoint<FlintTopicTaskResponse> {
        Endpoint(
            method: .post, path: "/flint/topics/\(id)/tasks",
            body: try? JSONEncoder().encode(request),
            contentType: "application/json",
            headers: ["If-Match": etag]
        )
    }

    public static func updateTask(id: String, taskID: String, request: FlintTopicTaskUpdate, etag: String) -> Endpoint<FlintTopicTaskResponse> {
        Endpoint(
            method: .patch, path: "/flint/topics/\(id)/tasks/\(taskID)",
            body: try? JSONEncoder().encode(request),
            contentType: "application/json",
            headers: ["If-Match": etag]
        )
    }
}
