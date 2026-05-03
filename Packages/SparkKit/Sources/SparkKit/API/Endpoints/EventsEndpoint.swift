import Foundation

public enum EventsEndpoint {
    /// GET /events/{id}
    public static func detail(id: String) -> Endpoint<EventDetail> {
        Endpoint(method: .get, path: "/events/\(id)")
    }

    /// PATCH /events/{id}/note
    public static func updateNote(id: String, note: String?) -> Endpoint<EventDetail> {
        let body = try? JSONEncoder().encode(UpdateNoteRequest(note: note))
        return Endpoint(method: .patch, path: "/events/\(id)/note", body: body)
    }
}

private struct UpdateNoteRequest: Encodable {
    let note: String?
}
