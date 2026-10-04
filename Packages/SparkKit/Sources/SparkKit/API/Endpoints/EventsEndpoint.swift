import Foundation

public enum EventsEndpoint {
    /// GET /events/{id}
    public static func detail(id: String) -> Endpoint<EventDetail> {
        Endpoint(method: .get, path: "/events/\(id)")
    }

    /// GET /events/{id}/route
    ///
    /// Read-only GPS route. Only call it when the detail has `hasRoute`; the
    /// server answers 404 for events without one. The caller keeps no local
    /// copy, so it skips the ETag cache (a 304 would leave nothing to draw).
    public static func route(id: String) -> Endpoint<EventRoute> {
        Endpoint(method: .get, path: "/events/\(id)/route", usesETag: false)
    }

    /// PATCH /events/{id}/note
    ///
    /// The route requires the event's current ETag; without it the server
    /// answers 428 and the note is never saved.
    public static func updateNote(id: String, note: String?, etag: String) -> Endpoint<EventDetail> {
        let body = try? JSONEncoder().encode(UpdateNoteRequest(note: note))
        return Endpoint(method: .patch, path: "/events/\(id)/note", body: body, headers: ["If-Match": etag])
    }

    /// DELETE /events/{id}
    ///
    /// Soft delete, guarded by the event's current ETag. Undo with `restore`.
    public static func delete(id: String, etag: String) -> Endpoint<DeletedEntity> {
        Endpoint(method: .delete, path: "/events/\(id)", headers: ["If-Match": etag])
    }

    /// POST /events/{id}/restore
    ///
    /// Undo for `delete`. Idempotent, so it carries no `If-Match`.
    public static func restore(id: String) -> Endpoint<EventDetail> {
        Endpoint(method: .post, path: "/events/\(id)/restore")
    }

    /// POST /knowledge/events/{id}/reprocess
    public static func reprocessKnowledgeEvent(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .post, path: "/knowledge/events/\(id)/reprocess")
    }
}

private struct UpdateNoteRequest: Encodable {
    let note: String?
}
