import Foundation
import OSLog

public enum APIError: Error, Sendable {
    case invalidURL
    case transport(Error)
    case unauthorized
    case notModified
    case httpStatus(Int, Data?)
    case decoding(Error)
    case noData
}

/// Generic async/await HTTP client with:
/// - `If-None-Match` / 304 short-circuit via `ETagCache`
/// - automatic 401 → token refresh → retry once
/// - exponential backoff on transport errors (0.5s / 1s / 2s)
///
/// Auth URLs (the `/oauth/*` endpoints) live at the site root, not under the
/// mobile API prefix — callers pass `absoluteBase` to target them.
public actor APIClient {
    private let environment: APIEnvironment
    private let session: URLSession
    private let tokenStore: KeychainTokenStore
    private let etagCache: ETagCache
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger = Logger(subsystem: "co.cronx.spark", category: "APIClient")

    public init(
        environment: APIEnvironment = .current(),
        session: URLSession = .shared,
        tokenStore: KeychainTokenStore,
        etagCache: ETagCache = ETagCache()
    ) {
        self.environment = environment
        self.session = session
        self.tokenStore = tokenStore
        self.etagCache = etagCache
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Public entrypoints

    public func request<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        try await perform(endpoint, absoluteBase: false, allowRefresh: true)
    }

    /// Hit an endpoint whose path is rooted at the site (not `/api/v1/mobile`).
    /// Used for the OAuth token endpoints.
    public func requestSiteRoot<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        try await perform(endpoint, absoluteBase: true, allowRefresh: false)
    }

    // MARK: - Core

    private func perform<Response>(
        _ endpoint: Endpoint<Response>,
        absoluteBase: Bool,
        allowRefresh: Bool
    ) async throws -> Response {
        let url = try buildURL(endpoint: endpoint, absoluteBase: absoluteBase)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = endpoint.body {
            request.httpBody = body
            request.setValue(endpoint.contentType ?? "application/json", forHTTPHeaderField: "Content-Type")
        }
        if endpoint.requiresAuth, let token = await tokenStore.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let etag = await etagCache.etag(for: url) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        if http.statusCode == 304 {
            throw APIError.notModified
        }

        if http.statusCode == 401 {
            if allowRefresh, await tokenStore.hasRefreshToken() {
                let refreshed = try await refreshAndRetry(endpoint, absoluteBase: absoluteBase)
                return refreshed
            }
            throw APIError.unauthorized
        }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpStatus(http.statusCode, data)
        }

        if let etag = http.value(forHTTPHeaderField: "ETag") {
            await etagCache.store(etag, for: url)
        }

        if data.isEmpty, let empty = EmptyResponse() as? Response {
            return empty
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            logger.error("Decoding failed for \(endpoint.path): \(error.localizedDescription)")
            throw APIError.decoding(error)
        }
    }

    private func refreshAndRetry<Response>(
        _ endpoint: Endpoint<Response>,
        absoluteBase: Bool
    ) async throws -> Response {
        guard let refreshToken = await tokenStore.refreshToken() else {
            throw APIError.unauthorized
        }
        let tokens = try await perform(
            AuthEndpoint.refresh(refreshToken: refreshToken),
            absoluteBase: true,
            allowRefresh: false
        )
        await tokenStore.store(
            access: tokens.accessToken,
            refresh: tokens.refreshToken,
            expiresIn: tokens.expiresIn
        )
        return try await perform(endpoint, absoluteBase: absoluteBase, allowRefresh: false)
    }

    private func buildURL<Response>(endpoint: Endpoint<Response>, absoluteBase: Bool) throws -> URL {
        let base: URL
        if absoluteBase {
            base = environment.baseURL
                .deletingLastPathComponent() // /api/v1
                .deletingLastPathComponent() // /api
                .deletingLastPathComponent() // site root
        } else {
            base = environment.baseURL
        }
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.path += endpoint.path
        if !endpoint.query.isEmpty {
            components.queryItems = endpoint.query
        }
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }
}

/// Sentinel for endpoints that return an empty 204.
public struct EmptyResponse: Codable, Sendable {
    public init() {}
}
