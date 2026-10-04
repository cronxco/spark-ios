import Foundation

public enum IntegrationsEndpoint {
    public struct ListResponse: Decodable, Sendable {
        public let data: [Integration]
    }

    /// GET /integrations
    public static func list() -> Endpoint<ListResponse> {
        Endpoint(method: .get, path: "/integrations")
    }

    /// GET /integrations/{id}
    public static func detail(id: String) -> Endpoint<IntegrationDetail> {
        Endpoint(method: .get, path: "/integrations/\(id)")
    }

    /// GET /integrations/{id} without `If-None-Match`, for reads that need the
    /// body and a fresh `ETag` — a first load, or the re-read before retrying a
    /// conditional write — and must never get a 304.
    public static func detailForWrite(id: String) -> Endpoint<IntegrationDetail> {
        Endpoint(method: .get, path: "/integrations/\(id)", usesETag: false)
    }

    /// POST /integrations/{id}/sync — the backend requires `If-Match`; pass
    /// the detail read's ETag.
    public static func syncNow(id: String, etag: String? = nil) -> Endpoint<EmptyResponse> {
        Endpoint(method: .post, path: "/integrations/\(id)/sync").withIfMatch(etag)
    }

    /// POST /integrations/{id}/pause — pause or resume scheduled fetches.
    /// The backend requires `If-Match`; pass the detail read's ETag.
    public static func setPaused(id: String, paused: Bool, etag: String?) -> Endpoint<Integration> {
        struct Request: Encodable { let paused: Bool }
        return Endpoint(
            method: .post,
            path: "/integrations/\(id)/pause",
            body: try? JSONEncoder().encode(Request(paused: paused))
        ).withIfMatch(etag)
    }

    public static func syncService(_ service: String) -> Endpoint<BulkSyncResponse> {
        struct Request: Encodable { let service: String }
        return Endpoint(method: .post, path: "/integrations/sync", body: try? JSONEncoder().encode(Request(service: service)))
    }

    public struct OAuthStartResponse: Decodable, Sendable {
        public let url: URL
    }

    /// POST /integrations/{id}/oauth/start — returns the URL to open in
    /// `ASWebAuthenticationSession` for re-authorisation.
    public static func oauthStart(id: String) -> Endpoint<OAuthStartResponse> {
        Endpoint(method: .post, path: "/integrations/\(id)/oauth/start")
    }
}

public struct BulkSyncResponse: Codable, Sendable { public let service: String; public let totalJobsDispatched: Int; enum CodingKeys: String, CodingKey { case service; case totalJobsDispatched = "total_jobs_dispatched" } }
