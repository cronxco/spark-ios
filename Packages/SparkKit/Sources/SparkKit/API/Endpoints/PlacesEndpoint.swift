import Foundation

public enum PlacesEndpoint {
    /// GET /places/{id}
    public static func detail(id: String) -> Endpoint<PlaceDetail> {
        Endpoint(method: .get, path: "/places/\(id)")
    }
}
