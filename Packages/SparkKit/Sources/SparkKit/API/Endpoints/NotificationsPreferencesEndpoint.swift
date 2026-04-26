import Foundation

public enum NotificationsPreferencesEndpoint {
    /// GET /settings/notifications
    public static func get() -> Endpoint<NotificationPreferences> {
        Endpoint(method: .get, path: "/settings/notifications")
    }

    /// PATCH /settings/notifications
    public static func update(_ prefs: NotificationPreferences) -> Endpoint<EmptyResponse> {
        let body = try? JSONEncoder().encode(prefs)
        return Endpoint(method: .patch, path: "/settings/notifications", body: body, contentType: "application/json")
    }
}
