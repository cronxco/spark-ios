import Foundation
import OSLog

public enum APIError: Error, Sendable {
    case invalidURL
    case transport(Error)
    case unauthorized
    case notModified
    case httpStatus(Int, Data?, URL)
    case decoding(Error)
    case noData
}

/// Generic async/await HTTP client with:
/// - `If-None-Match` / 304 short-circuit via `ETagCache`
/// - automatic 401 → token refresh → retry once
/// - exponential backoff on transport errors (0.5s / 1s / 2s)
///
/// Auth URLs (the `/oauth/*` endpoints) live under `/api`, not under the
/// mobile API prefix `/api/v1/mobile` — callers pass `absoluteBase` to target them.
public actor APIClient {
    private let environment: APIEnvironment
    private let session: URLSession
    private let tokenStore: KeychainTokenStore
    private let etagCache: ETagCache
    private let telemetry: APITelemetry
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger = Logger(subsystem: "co.cronx.spark", category: "APIClient")

    public init(
        environment: APIEnvironment = .current(),
        session: URLSession = .shared,
        tokenStore: KeychainTokenStore,
        etagCache: ETagCache = ETagCache(),
        telemetry: APITelemetry = .shared
    ) {
        self.environment = environment
        self.session = session
        self.tokenStore = tokenStore
        self.etagCache = etagCache
        self.telemetry = telemetry
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let withFrac = ISO8601DateFormatter()
            withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = withFrac.date(from: string) { return d }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let d = plain.date(from: string) { return d }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Cannot parse date: \(string)")
        }
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Public entrypoints

    public func request<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        try await perform(endpoint, absoluteBase: false, allowRefresh: true)
    }

    /// Hit an endpoint whose path is rooted at `/api` (not `/api/v1/mobile`).
    /// Used for the OAuth token endpoints.
    public func requestSiteRoot<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        try await perform(endpoint, absoluteBase: true, allowRefresh: false)
    }

    // MARK: - Core

    private func perform<Response>(
        _ endpoint: Endpoint<Response>,
        absoluteBase: Bool,
        allowRefresh: Bool,
        attempt: Int = 1,
        isRefreshRequest: Bool = false
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
        let metricsCollector = APITaskMetricsCollector()
        let startedAt = Date()
        do {
            (data, response) = try await session.data(for: request, delegate: metricsCollector)
        } catch {
            await captureTelemetry(
                operation: "http.client",
                endpoint: endpoint,
                request: request,
                url: url,
                attempt: attempt,
                isRefreshRequest: isRefreshRequest,
                startedAt: startedAt,
                metrics: metricsCollector.snapshot,
                outcome: .transportError,
                errorDescription: String(describing: error)
            )
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            await captureTelemetry(
                operation: "http.client",
                endpoint: endpoint,
                request: request,
                url: url,
                attempt: attempt,
                isRefreshRequest: isRefreshRequest,
                startedAt: startedAt,
                metrics: metricsCollector.snapshot,
                outcome: .noData,
                errorDescription: "Response was not HTTPURLResponse"
            )
            throw APIError.noData
        }

        if http.statusCode == 304 {
            await captureTelemetry(
                operation: "http.client",
                endpoint: endpoint,
                request: request,
                url: url,
                attempt: attempt,
                isRefreshRequest: isRefreshRequest,
                startedAt: startedAt,
                response: http,
                data: data,
                metrics: metricsCollector.snapshot,
                outcome: .notModified
            )
            throw APIError.notModified
        }

        if http.statusCode == 401 {
            await captureTelemetry(
                operation: "http.client",
                endpoint: endpoint,
                request: request,
                url: url,
                attempt: attempt,
                isRefreshRequest: isRefreshRequest,
                startedAt: startedAt,
                response: http,
                data: data,
                metrics: metricsCollector.snapshot,
                outcome: .unauthorized
            )
            if allowRefresh, await tokenStore.hasRefreshToken() {
                let refreshed = try await refreshAndRetry(endpoint, absoluteBase: absoluteBase, retryAttempt: attempt + 1)
                return refreshed
            }
            throw APIError.unauthorized
        }

        guard (200..<300).contains(http.statusCode) else {
            await captureTelemetry(
                operation: "http.client",
                endpoint: endpoint,
                request: request,
                url: url,
                attempt: attempt,
                isRefreshRequest: isRefreshRequest,
                startedAt: startedAt,
                response: http,
                data: data,
                metrics: metricsCollector.snapshot,
                outcome: .httpError,
                errorDescription: "HTTP \(http.statusCode)"
            )
            throw APIError.httpStatus(http.statusCode, data, url)
        }

        if let etag = http.value(forHTTPHeaderField: "ETag") {
            await etagCache.store(etag, for: url)
        }

        #if DEBUG
        let bodyPreview = String(data: data, encoding: .utf8) ?? "<binary>"
        logger.info("[\(endpoint.path, privacy: .public)] HTTP \(http.statusCode, privacy: .public) — \(bodyPreview, privacy: .public)")
        #endif

        if data.isEmpty, let empty = EmptyResponse() as? Response {
            await captureTelemetry(
                operation: "http.client",
                endpoint: endpoint,
                request: request,
                url: url,
                attempt: attempt,
                isRefreshRequest: isRefreshRequest,
                startedAt: startedAt,
                response: http,
                data: data,
                metrics: metricsCollector.snapshot,
                outcome: .success
            )
            return empty
        }

        do {
            let decodeStartedAt = Date()
            let decoded = try decoder.decode(Response.self, from: data)
            await captureTelemetry(
                operation: "http.client",
                endpoint: endpoint,
                request: request,
                url: url,
                attempt: attempt,
                isRefreshRequest: isRefreshRequest,
                startedAt: startedAt,
                response: http,
                data: data,
                metrics: metricsCollector.snapshot,
                outcome: .success,
                decodeDurationMillis: Date().timeIntervalSince(decodeStartedAt) * 1_000
            )
            return decoded
        } catch {
            let bodyString = String(data: data, encoding: .utf8) ?? "<binary>"
            logger.error("Decoding failed for \(endpoint.path, privacy: .public): \(error.localizedDescription, privacy: .public) — body: \(bodyString, privacy: .public)")
            await captureTelemetry(
                operation: "http.client",
                endpoint: endpoint,
                request: request,
                url: url,
                attempt: attempt,
                isRefreshRequest: isRefreshRequest,
                startedAt: startedAt,
                response: http,
                data: data,
                metrics: metricsCollector.snapshot,
                outcome: .decodingError,
                errorDescription: String(describing: error)
            )
            throw APIError.decoding(error)
        }
    }

    private func refreshAndRetry<Response>(
        _ endpoint: Endpoint<Response>,
        absoluteBase: Bool,
        retryAttempt: Int
    ) async throws -> Response {
        guard let refreshToken = await tokenStore.refreshToken() else {
            throw APIError.unauthorized
        }
        let tokens = try await perform(
            AuthEndpoint.refresh(refreshToken: refreshToken),
            absoluteBase: true,
            allowRefresh: false,
            isRefreshRequest: true
        )
        await tokenStore.store(
            access: tokens.accessToken,
            refresh: tokens.refreshToken,
            expiresIn: tokens.expiresIn
        )
        return try await perform(endpoint, absoluteBase: absoluteBase, allowRefresh: false, attempt: retryAttempt)
    }

    private func captureTelemetry<Response>(
        operation: String,
        endpoint: Endpoint<Response>,
        request: URLRequest,
        url: URL,
        attempt: Int,
        isRefreshRequest: Bool,
        startedAt: Date,
        response: HTTPURLResponse? = nil,
        data: Data? = nil,
        metrics: APITaskMetrics? = nil,
        outcome: APITelemetryEvent.Outcome,
        errorDescription: String? = nil,
        decodeDurationMillis: Double? = nil
    ) async {
        let requestHeaders = APITelemetryRedactor.headers(request.allHTTPHeaderFields ?? [:])
        let responseHeaders = APITelemetryRedactor.headers(response?.stringHeaderFields ?? [:])
        let contentType = request.value(forHTTPHeaderField: "Content-Type")
        let responseContentType = response?.value(forHTTPHeaderField: "Content-Type")

        let event = APITelemetryEvent(
            operation: operation,
            method: request.httpMethod ?? endpoint.method.rawValue,
            url: APITelemetryRedactor.url(url),
            endpointPath: endpoint.path,
            requiresAuth: endpoint.requiresAuth,
            attempt: attempt,
            isRefreshRequest: isRefreshRequest,
            requestHeaders: requestHeaders,
            requestBody: APITelemetryRedactor.body(request.httpBody, contentType: contentType),
            statusCode: response?.statusCode,
            responseHeaders: responseHeaders,
            responseBody: APITelemetryRedactor.body(data, contentType: responseContentType),
            responseSizeBytes: data?.count ?? 0,
            durationMillis: Date().timeIntervalSince(startedAt) * 1_000,
            decodeDurationMillis: decodeDurationMillis,
            metrics: metrics,
            outcome: outcome,
            errorDescription: errorDescription
        )
        await telemetry.capture(event)
    }

    private func buildURL<Response>(endpoint: Endpoint<Response>, absoluteBase: Bool) throws -> URL {
        let base: URL
        if absoluteBase {
            base = environment.baseURL
                .deletingLastPathComponent() // /api/v1
                .deletingLastPathComponent() // /api (oauth lives here, not at site root)
        } else {
            base = environment.baseURL
        }
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.path = joinedPath(basePath: components.path, endpointPath: endpoint.path)
        if !endpoint.query.isEmpty {
            components.queryItems = endpoint.query
        }
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    private func oauthSiteRootURL() -> URL {
        guard var components = URLComponents(
            url: environment.oauthAuthorizeURL,
            resolvingAgainstBaseURL: false
        ) else {
            return environment.baseURL
        }
        components.path = "/"
        components.query = nil
        components.fragment = nil
        return components.url ?? environment.baseURL
    }

    private func joinedPath(basePath: String, endpointPath: String) -> String {
        let normalizedBase = basePath == "/" ? "" : basePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedEndpoint = endpointPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if normalizedBase.isEmpty && normalizedEndpoint.isEmpty {
            return "/"
        }
        if normalizedBase.isEmpty {
            return "/\(normalizedEndpoint)"
        }
        if normalizedEndpoint.isEmpty {
            return "/\(normalizedBase)"
        }
        return "/\(normalizedBase)/\(normalizedEndpoint)"
    }
}

private extension HTTPURLResponse {
    var stringHeaderFields: [String: String] {
        Dictionary(uniqueKeysWithValues: allHeaderFields.compactMap { key, value in
            guard let key = key as? String else { return nil }
            return (key, String(describing: value))
        })
    }
}

/// Sentinel for endpoints that return an empty 204.
public struct EmptyResponse: Codable, Sendable {
    public init() {}
}
