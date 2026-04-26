import Foundation

public enum MeEndpoint {
    /// GET /me
    public static func get() -> Endpoint<UserProfile> {
        Endpoint(method: .get, path: "/me")
    }
}
