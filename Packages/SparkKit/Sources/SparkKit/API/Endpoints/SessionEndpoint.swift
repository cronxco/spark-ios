import Foundation

public enum SessionEndpoint {
    /// POST /logout — ends the calling session server-side.
    ///
    /// Revokes the paired OAuth refresh token and deletes the access token
    /// presenting the request. Scoped to this credential only: other devices
    /// and separately created personal access tokens are untouched.
    ///
    /// Requires only `ios:read`, so a read-only session can still sign itself
    /// out, and carries no `If-Match` — signing out must never be blocked by a
    /// precondition.
    public static func logout() -> Endpoint<EmptyResponse> {
        Endpoint(method: .post, path: "/logout")
    }
}
