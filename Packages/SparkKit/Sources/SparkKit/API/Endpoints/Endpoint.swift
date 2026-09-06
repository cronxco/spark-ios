import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// A type-safe description of an API call. `Response` is the decoded payload.
public struct Endpoint<Response: Decodable & Sendable>: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let query: [URLQueryItem]
    public let body: Data?
    public let contentType: String?
    public let requiresAuth: Bool
    public let headers: [String: String]

    /// Extra request headers.
    ///
    /// Chiefly `If-Match`: the backend guards destructive and last-write-wins
    /// mutations with a strong resource version and answers `428` without one.
    public let headers: [String: String]

    public init(
        method: HTTPMethod,
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        contentType: String? = nil,
        requiresAuth: Bool = true,
        headers: [String: String] = [:]
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
        self.contentType = contentType
        self.requiresAuth = requiresAuth
        self.headers = headers
    }

    /// The same endpoint carrying an `If-Match` precondition.
    public func withIfMatch(_ version: String?) -> Endpoint<Response> {
        guard let version, !version.isEmpty else { return self }

        var merged = headers
        merged["If-Match"] = version

        return Endpoint(
            method: method,
            path: path,
            query: query,
            body: body,
            contentType: contentType,
            requiresAuth: requiresAuth,
            headers: merged
        )
    }
}
