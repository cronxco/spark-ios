import Foundation

public enum ApiTokensEndpoint {
    /// GET /api-tokens
    public static func list() -> Endpoint<[ApiToken]> {
        Endpoint(method: .get, path: "/api-tokens")
    }

    /// POST /api-tokens — returns `CreatedApiToken` containing the one-time plaintext.
    public static func create(name: String, abilities: [String] = ["mcp:read"]) -> Endpoint<CreatedApiToken> {
        let body = try? JSONEncoder().encode(CreateRequest(name: name, abilities: abilities))
        return Endpoint(method: .post, path: "/api-tokens", body: body, contentType: "application/json")
    }

    private struct CreateRequest: Encodable {
        let name: String
        let abilities: [String]
    }
}
