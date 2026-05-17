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

    public struct OAuthStartResponse: Decodable, Sendable {
        public let url: URL
    }

    /// POST /integrations/{id}/oauth/start — returns the URL to open in
    /// `ASWebAuthenticationSession` for re-authorisation.
    public static func oauthStart(id: String) -> Endpoint<OAuthStartResponse> {
        Endpoint(method: .post, path: "/integrations/\(id)/oauth/start")
    }
}
