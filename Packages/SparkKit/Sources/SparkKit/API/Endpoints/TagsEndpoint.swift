import Foundation

public enum TagsEndpoint {
    /// GET /tags — browse by usage or query text, cursor-paginated.
    public static func list(query: String? = nil, cursor: String? = nil, limit: Int = 30) -> Endpoint<TagPage> {
        Endpoint(method: .get, path: "/tags", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "cursor", value: cursor),
            URLQueryItem(name: "limit", value: String(limit)),
        ].compactMap { $0.value == nil ? nil : $0 })
    }

    public static func suggest(query: String, limit: Int = 10) -> Endpoint<TagPage> {
        Endpoint(method: .get, path: "/tags/suggest", query: [
            URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    public static func detail(id: String, cursor: String? = nil, limit: Int = 30) -> Endpoint<TagDetailPage> {
        Endpoint(method: .get, path: "/tags/\(id)", query: [
            URLQueryItem(name: "cursor", value: cursor), URLQueryItem(name: "limit", value: String(limit)),
        ].compactMap { $0.value == nil ? nil : $0 })
    }

    public static func attach<Response: Decodable & Sendable>(
        kind: SparkEntityKind,
        id: String,
        request: TagMutationRequest,
        etag: String,
        response: Response.Type
    ) -> Endpoint<Response> {
        Endpoint(
            method: .post,
            path: "/\(kind.rawValue)/\(id)/tags",
            body: try? JSONEncoder().encode(request),
            headers: ["If-Match": etag]
        )
    }

    public static func detach<Response: Decodable & Sendable>(
        kind: SparkEntityKind,
        id: String,
        tagID: String,
        etag: String,
        response: Response.Type
    ) -> Endpoint<Response> {
        Endpoint(
            method: .delete,
            path: "/\(kind.rawValue)/\(id)/tags/\(tagID)",
            headers: ["If-Match": etag]
        )
    }
}
