import Foundation

public enum AuthEndpoint {
    /// POST /oauth/token — exchange an authorisation code for an access token.
    /// Note: this endpoint lives under /api, not /api/v1/mobile.
    public static func exchange(code: String, verifier: String) -> Endpoint<TokenResponse> {
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": verifier,
            "client_id": "ios",
            "redirect_uri": "spark://auth/callback",
        ]
        return Endpoint(
            method: .post,
            path: "/oauth/token",
            body: try? JSONSerialization.data(withJSONObject: body),
            contentType: "application/json",
            requiresAuth: false
        )
    }

    /// POST /oauth/refresh — rotate refresh token.
    public static func refresh(refreshToken: String) -> Endpoint<TokenResponse> {
        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": "ios",
        ]
        return Endpoint(
            method: .post,
            path: "/oauth/refresh",
            body: try? JSONSerialization.data(withJSONObject: body),
            contentType: "application/json",
            requiresAuth: false
        )
    }
}

public struct TokenResponse: Codable, Sendable, Hashable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}
