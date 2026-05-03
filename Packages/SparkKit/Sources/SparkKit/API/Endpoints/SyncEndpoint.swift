import Foundation

/// Endpoints for delta-sync between the server and local SwiftData cache.
/// The delta response shape is defined in App\Services\Mobile\DeltaSync (backend).
public enum SyncEndpoint {
    /// GET /sync/delta?since={cursor}
    /// Returns events that changed since the cursor. No cursor = last 24h.
    public static func delta(since cursor: String?) -> Endpoint<DeltaResponse> {
        var query: [URLQueryItem] = []
        if let cursor {
            query.append(URLQueryItem(name: "since", value: cursor))
        }
        return Endpoint(method: .get, path: "/sync/delta", query: query)
    }

    /// Wire-format response. Shape is load-bearing — only change through
    /// an explicit backend migration coordinated with the iOS release.
    public struct DeltaResponse: Decodable, Sendable {
        public let created: [Event]
        public let updated: [Event]
        public let deleted: [String]
        /// Opaque cursor string: "{iso8601_updated_at}|{uuid}" or plain ISO-8601.
        public let nextCursor: String

        enum CodingKeys: String, CodingKey {
            case created, updated, deleted
            case nextCursor = "next_cursor"
        }
    }
}
