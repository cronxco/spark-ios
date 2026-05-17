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

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API URL is invalid."
        case .transport(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .notModified:
            return "The requested data has not changed."
        case .httpStatus(let status, let data, let url):
            return Self.httpStatusDescription(status: status, data: data, url: url)
        case .decoding(let error):
            return "The server response could not be read: \(error.localizedDescription)"
        case .noData:
            return "The server returned an invalid response."
        }
    }

    private static func httpStatusDescription(status: Int, data: Data?, url: URL) -> String {
        let serverMessage = data.flatMap(Self.serverMessage)
        let base = "HTTP \(status) from \(url.path)"
        guard let serverMessage, serverMessage.isEmpty == false else {
            return base
        }
        return "\(base): \(serverMessage)"
    }

    private static func serverMessage(from data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["message", "error", "detail", "title"] {
                if let message = object[key] as? String {
                    return message
                }
            }
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public extension APIError {
    var isCancellation: Bool {
        switch self {
        case .transport(let error):
            return error.isAPICancellation
        default:
            return false
        }
    }
}

public extension Error {
    var isAPICancellation: Bool {
        if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) {
            if self is CancellationError {
                return true
            }
        }
        if let apiError = self as? APIError {
            return apiError.isCancellation
        }
        if let urlError = self as? URLError {
            return urlError.code == .cancelled
        }
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == URLError.cancelled.rawValue
    }
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
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "APIClient")
    private static let refreshCoordinator = TokenRefreshCoordinator()

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
        let accessToken = endpoint.requiresAuth ? await tokenStore.accessToken() : nil
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
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
            if error.isAPICancellation {
                throw APIError.transport(error)
            }
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
                let refreshed = try await refreshAndRetry(
                    endpoint,
                    absoluteBase: absoluteBase,
                    retryAttempt: attempt + 1,
                    tokenUsedForRequest: accessToken
                )
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
        retryAttempt: Int,
        tokenUsedForRequest: String?
    ) async throws -> Response {
        if let tokenUsedForRequest,
           let currentAccessToken = await tokenStore.accessToken(),
           currentAccessToken != tokenUsedForRequest {
            return try await perform(endpoint, absoluteBase: absoluteBase, allowRefresh: false, attempt: retryAttempt)
        }

        _ = try await refreshTokens()
        return try await perform(endpoint, absoluteBase: absoluteBase, allowRefresh: false, attempt: retryAttempt)
    }

    private func refreshTokens() async throws -> AuthTokens {
        guard let refreshToken = await tokenStore.refreshToken() else {
            throw APIError.unauthorized
        }

        do {
            return try await Self.refreshCoordinator.refresh(refreshToken: refreshToken) { [tokenStore] in
                let tokens = try await self.perform(
                    AuthEndpoint.refresh(refreshToken: refreshToken),
                    absoluteBase: true,
                    allowRefresh: false,
                    isRefreshRequest: true
                )
                let authTokens = AuthTokens(
                    accessToken: tokens.accessToken,
                    refreshToken: tokens.refreshToken,
                    expiresIn: tokens.expiresIn
                )
                await tokenStore.store(
                    access: authTokens.accessToken,
                    refresh: authTokens.refreshToken,
                    expiresIn: authTokens.expiresIn
                )
                return authTokens
            }
        } catch {
            if case APIError.unauthorized = error {
                let currentRefreshToken = await tokenStore.refreshToken()
                if currentRefreshToken == nil || currentRefreshToken == refreshToken {
                    await tokenStore.clear()
                }
            }
            throw error
        }
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
            base = oauthSiteRootURL()
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

private actor TokenRefreshCoordinator {
    private var tasks: [String: Task<AuthTokens, Error>] = [:]

    func refresh(
        refreshToken: String,
        operation: @escaping @Sendable () async throws -> AuthTokens
    ) async throws -> AuthTokens {
        if let task = tasks[refreshToken] {
            return try await task.value
        }

        let task = Task {
            try await operation()
        }
        tasks[refreshToken] = task

        do {
            let tokens = try await task.value
            tasks[refreshToken] = nil
            return tokens
        } catch {
            tasks[refreshToken] = nil
            throw error
        }
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
