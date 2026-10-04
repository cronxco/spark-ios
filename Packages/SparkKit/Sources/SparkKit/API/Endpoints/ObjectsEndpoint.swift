import Foundation

public enum ObjectsEndpoint {
    /// GET /objects/{id}
    public static func detail(id: String) -> Endpoint<ObjectDetail> {
        Endpoint(method: .get, path: "/objects/\(id)")
    }

    /// DELETE /objects/{id}
    ///
    /// Soft delete, guarded by the object's current ETag. Its events are kept.
    /// Undo with `restore`.
    public static func delete(id: String, etag: String) -> Endpoint<DeletedEntity> {
        Endpoint(method: .delete, path: "/objects/\(id)", headers: ["If-Match": etag])
    }

    /// POST /objects/{id}/restore
    ///
    /// Undo for `delete`. Idempotent, so it carries no `If-Match`. The body has
    /// no recent events; re-read the detail to show them.
    public static func restore(id: String) -> Endpoint<ObjectDetail> {
        Endpoint(method: .post, path: "/objects/\(id)/restore")
    }
}
