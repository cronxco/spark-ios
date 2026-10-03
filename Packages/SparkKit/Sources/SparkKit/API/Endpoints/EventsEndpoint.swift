import Foundation

public enum EventsEndpoint {
    /// GET /events/{id}
    public static func detail(id: String) -> Endpoint<EventDetail> {
        Endpoint(method: .get, path: "/events/\(id)")
    }

    /// PATCH /events/{id}/note
    ///
    /// The route requires the event's current ETag; without it the server
    /// answers 428 and the note is never saved.
    public static func updateNote(id: String, note: String?, etag: String) -> Endpoint<EventDetail> {
        let body = try? JSONEncoder().encode(UpdateNoteRequest(note: note))
        return Endpoint(method: .patch, path: "/events/\(id)/note", body: body, headers: ["If-Match": etag])
    }

    /// POST /knowledge/events/{id}/reprocess
    public static func reprocessKnowledgeEvent(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .post, path: "/knowledge/events/\(id)/reprocess")
    }
}

private struct UpdateNoteRequest: Encodable {
    let note: String?
}
