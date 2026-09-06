import Foundation

public enum NotificationsPreferencesEndpoint {
    /// GET /settings/notifications
    public static func get() -> Endpoint<NotificationPreferences> {
        Endpoint(method: .get, path: "/settings/notifications")
    }

    /// PATCH /settings/notifications
    ///
    /// Guarded by `if-match:user`: the backend answers `428` without a
    /// precondition and `412` with a stale one. Pass the `ETag` from `get()`,
    /// which returns the strong user version this compares against.
    ///
    /// This is a genuine last-write-wins surface, so unlike marking
    /// notifications read it keeps its precondition deliberately.
    public static func update(
        _ prefs: NotificationPreferences,
        version: String?
    ) -> Endpoint<EmptyResponse> {
        let body = try? JSONEncoder().encode(prefs)
        return Endpoint(
            method: .patch,
            path: "/settings/notifications",
            body: body,
            contentType: "application/json"
        ).withIfMatch(version)
    }
}
