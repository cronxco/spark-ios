import Foundation

public enum LiveActivitiesEndpoint {
    /// Register or update the APNs push token for a Live Activity.
    /// Called whenever `Activity.pushTokenUpdates` emits a new token.
    public static func registerToken(
        activityID: String,
        token: String,
        type: String
    ) -> Endpoint<EmptyResponse> {
        let body = try? JSONEncoder().encode([
            "token": token,
            "type": type,
        ])
        return Endpoint(
            method: .post,
            path: "/live-activities/\(activityID)/tokens",
            body: body,
            contentType: "application/json"
        )
    }

    /// Notify the server the Live Activity has ended.
    public static func end(activityID: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .delete, path: "/live-activities/\(activityID)")
    }

    /// An empty server response — used when we only care about the status code.
    public struct EmptyResponse: Decodable, Sendable {}
}
