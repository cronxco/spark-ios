import Foundation

public enum TaggableEntity: String, Sendable, Hashable {
    case event = "events"
    case object = "objects"
}

public enum TagsEndpoint {
    public static func index(
        query text: String? = nil,
        cursor: String? = nil,
        limit: Int = 30
    ) -> Endpoint<Page<Tag>> {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let text, !text.isEmpty {
            query.append(URLQueryItem(name: "q", value: text))
        }
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(method: .get, path: "/tags", query: query)
    }

    public static func detail(
        id: String,
        cursor: String? = nil,
        limit: Int = 30
    ) -> Endpoint<TagDetailPage> {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(method: .get, path: "/tags/\(id)", query: query)
    }

    public static func suggest(query text: String, limit: Int = 10) -> Endpoint<TagSuggestions> {
        Endpoint(
            method: .get,
            path: "/tags/suggest",
            query: [
                URLQueryItem(name: "q", value: text),
                URLQueryItem(name: "limit", value: String(limit)),
            ],
            usesETag: false
        )
    }

    public static func add(
        entity: TaggableEntity,
        id: String,
        tagID: String
    ) -> Endpoint<TagMutationResponse> {
        let body = try? JSONEncoder().encode(AddTagRequest(tagID: tagID, name: nil, type: nil))
        return Endpoint(
            method: .post,
            path: "/\(entity.rawValue)/\(id)/tags",
            body: body,
            usesETag: false
        )
    }

    public static func createAndAdd(
        entity: TaggableEntity,
        id: String,
        name: String,
        type: String? = nil
    ) -> Endpoint<TagMutationResponse> {
        let body = try? JSONEncoder().encode(AddTagRequest(tagID: nil, name: name, type: type))
        return Endpoint(
            method: .post,
            path: "/\(entity.rawValue)/\(id)/tags",
            body: body,
            usesETag: false
        )
    }

    public static func remove(
        entity: TaggableEntity,
        id: String,
        tagID: String
    ) -> Endpoint<TagMutationResponse> {
        Endpoint(
            method: .delete,
            path: "/\(entity.rawValue)/\(id)/tags/\(tagID)",
            usesETag: false
        )
    }
}

private struct AddTagRequest: Encodable {
    let tagID: String?
    let name: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case tagID = "tag_id"
        case name, type
    }
}
