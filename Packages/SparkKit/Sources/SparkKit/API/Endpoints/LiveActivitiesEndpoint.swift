import Foundation

public enum LiveActivitiesEndpoint {
    /// Create the backend record for a client-owned activity. This must happen
    /// once ActivityKit has produced its first push token.
    public static func create<State: Encodable>(
        activityID: String,
        token: String,
        type: String,
        contentState: State
    ) -> Endpoint<LiveActivityToken> {
        let body = try? JSONEncoder().encode(LiveActivityCreateRequest(
            activityID: activityID, token: token, type: type, contentState: AnyEncodable(contentState)
        ))
        return Endpoint(method: .post, path: "/live-activities", body: body, contentType: "application/json")
    }

    /// Register or update the APNs push token for a Live Activity.
    /// Called whenever `Activity.pushTokenUpdates` emits a new token.
    public static func registerToken(
        activityID: String,
        token: String
    ) -> Endpoint<LiveActivityToken> {
        let body = try? JSONEncoder().encode([
            "push_token": token,
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

    /// Mirror an in-app state update to the server. ActivityKit updates remain
    /// intentionally independent of this best-effort network request.
    public static func update<State: Encodable & Sendable>(
        activityID: String,
        state: State
    ) -> Endpoint<LiveActivityToken> {
        let body = try? JSONEncoder().encode(["content_state": AnyEncodable(state)])
        return Endpoint(method: .patch, path: "/live-activities/\(activityID)", body: body, contentType: "application/json")
    }

    /// An empty server response — used when we only care about the status code.
    public struct EmptyResponse: Decodable, Sendable {}
}

public struct LiveActivityToken: Codable, Sendable, Hashable {
    public let id: String
    public let activityID: String
    public let activityType: String?
    public let startsAt: Date?
    public let endsAt: Date?
    public let lastPushedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case activityID = "activity_id"
        case activityType = "activity_type"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case lastPushedAt = "last_pushed_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(String.self, forKey: .id) { id = value }
        else { id = String(try container.decode(Int.self, forKey: .id)) }
        activityID = try container.decode(String.self, forKey: .activityID)
        activityType = try container.decodeIfPresent(String.self, forKey: .activityType)
        startsAt = try container.decodeIfPresent(Date.self, forKey: .startsAt)
        endsAt = try container.decodeIfPresent(Date.self, forKey: .endsAt)
        lastPushedAt = try container.decodeIfPresent(Date.self, forKey: .lastPushedAt)
    }
}

private struct LiveActivityCreateRequest: Encodable {
    let activityID: String
    let token: String
    let type: String
    let contentState: AnyEncodable

    enum CodingKeys: String, CodingKey {
        case activityID = "activity_id"
        case token = "push_token"
        case type = "activity_type"
        case contentState = "content_state"
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) { encodeValue = value.encode }
    func encode(to encoder: Encoder) throws { try encodeValue(encoder) }
}
