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

    /// GET /events/{id} without `If-None-Match`, for the re-read before a
    /// conditional write: it must return the body and a fresh `ETag`, never 304.
    public static func detailForWrite(id: String) -> Endpoint<EventDetail> {
        Endpoint(method: .get, path: "/events/\(id)", usesETag: false)
    }

    /// POST /knowledge/events/{id}/reprocess — the backend requires `If-Match`
    /// with the event's current version and answers 202 once the work is queued.
    public static func reprocessKnowledgeEvent(id: String, etag: String) -> Endpoint<KnowledgeReprocessResponse> {
        Endpoint(method: .post, path: "/knowledge/events/\(id)/reprocess", headers: ["If-Match": etag])
    }
}

/// The 202 body from a knowledge reprocess request.
public struct KnowledgeReprocessResponse: Codable, Sendable, Equatable {
    public let eventId: String
    public let service: String
    public let status: String
    public let mode: String

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case service, status, mode
    }
}

private struct UpdateNoteRequest: Encodable {
    let note: String?
}
