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
