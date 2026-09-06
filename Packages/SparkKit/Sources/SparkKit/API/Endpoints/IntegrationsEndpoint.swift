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

    /// POST /integrations/{id}/sync
    public static func syncNow(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .post, path: "/integrations/\(id)/sync")
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
