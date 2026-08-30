import Foundation

public enum EntityMutationsEndpoint {
    public static func relationships(kind: SparkEntityKind, id: String) -> Endpoint<RelationshipListResponse> { Endpoint(method: .get, path: "/\(kind.rawValue)/\(id)/relationships") }
    public static func createRelationship(kind: SparkEntityKind, id: String, request: RelationshipCreateRequest, etag: String) throws -> Endpoint<EntityRelationship> { Endpoint(method: .post, path: "/\(kind.rawValue)/\(id)/relationships", body: try JSONEncoder().encode(request), headers: ["If-Match": etag]) }
    public static func deleteRelationship(id: String, etag: String) -> Endpoint<EmptyResponse> { Endpoint(method: .delete, path: "/relationships/\(id)", headers: ["If-Match": etag]) }
    public static func setLocation<Response: Decodable & Sendable>(kind: SparkEntityKind, id: String, location: LocationRequest, etag: String, response: Response.Type) throws -> Endpoint<Response> { Endpoint(method: .patch, path: "/\(kind.rawValue)/\(id)/location", body: try JSONEncoder().encode(location), headers: ["If-Match": etag]) }
    public static func clearLocation<Response: Decodable & Sendable>(kind: SparkEntityKind, id: String, etag: String, response: Response.Type) -> Endpoint<Response> { Endpoint(method: .delete, path: "/\(kind.rawValue)/\(id)/location", headers: ["If-Match": etag]) }
    public static func geocode<Response: Decodable & Sendable>(kind: SparkEntityKind, id: String, address: String, etag: String, response: Response.Type) throws -> Endpoint<Response> { Endpoint(method: .post, path: "/\(kind.rawValue)/\(id)/location/geocode", body: try JSONEncoder().encode(GeocodeLocationRequest(address: address)), headers: ["If-Match": etag]) }
    public static func update<Response: Decodable & Sendable, Attributes: Encodable>(kind: SparkEntityKind, id: String, attributes: Attributes, etag: String, response: Response.Type) throws -> Endpoint<Response> { Endpoint(method: .patch, path: "/\(kind.rawValue)/\(id)", body: try JSONEncoder().encode(attributes), headers: ["If-Match": etag]) }
}
