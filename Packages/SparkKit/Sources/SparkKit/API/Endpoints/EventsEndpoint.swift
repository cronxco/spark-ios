import Foundation

public enum EventsEndpoint {
    /// GET /events/{id}
    public static func detail(id: String) -> Endpoint<EventDetail> {
        Endpoint(method: .get, path: "/events/\(id)")
    }
}
