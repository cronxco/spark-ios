import Foundation

public protocol APITelemetrySink: Sendable {
    func capture(_ event: APITelemetryEvent) async
}

public actor APITelemetry {
    public static let shared = APITelemetry()

    private var sink: APITelemetrySink?

    public func setSink(_ sink: APITelemetrySink?) {
        self.sink = sink
    }

    public func capture(_ event: APITelemetryEvent) async {
        await sink?.capture(event)
    }
}

public struct APITelemetryEvent: Sendable {
    public enum Outcome: Sendable, Equatable {
        case success
        case notModified
        case unauthorized
        case httpError
        case transportError
        case decodingError
        case noData
    }

    public let id: UUID
    public let operation: String
    public let method: String
    public let url: URL
    public let endpointPath: String?
    public let requiresAuth: Bool
    public let attempt: Int
    public let isRefreshRequest: Bool
    public let requestHeaders: [String: String]
    public let requestBody: Data?
    public let statusCode: Int?
    public let responseHeaders: [String: String]
    public let responseBody: Data?
    public let responseSizeBytes: Int
    public let durationMillis: Double
    public let decodeDurationMillis: Double?
    public let metrics: APITaskMetrics?
    public let outcome: Outcome
    public let errorDescription: String?

    public init(
        id: UUID = UUID(),
        operation: String,
        method: String,
        url: URL,
        endpointPath: String? = nil,
        requiresAuth: Bool = false,
        attempt: Int = 1,
        isRefreshRequest: Bool = false,
        requestHeaders: [String: String] = [:],
        requestBody: Data? = nil,
        statusCode: Int? = nil,
        responseHeaders: [String: String] = [:],
        responseBody: Data? = nil,
        responseSizeBytes: Int = 0,
        durationMillis: Double,
        decodeDurationMillis: Double? = nil,
        metrics: APITaskMetrics? = nil,
        outcome: Outcome,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.operation = operation
        self.method = method
        self.url = url
        self.endpointPath = endpointPath
        self.requiresAuth = requiresAuth
        self.attempt = attempt
        self.isRefreshRequest = isRefreshRequest
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.statusCode = statusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.responseSizeBytes = responseSizeBytes
        self.durationMillis = durationMillis
        self.decodeDurationMillis = decodeDurationMillis
        self.metrics = metrics
        self.outcome = outcome
        self.errorDescription = errorDescription
    }
}

public struct APITaskMetrics: Sendable, Equatable {
    public let transactionCount: Int
    public let redirects: Int
    public let requestBodyBytesSent: Int64
    public let responseBodyBytesReceived: Int64
    public let fetchStartMillis: Double?
    public let domainLookupMillis: Double?
    public let connectMillis: Double?
    public let secureConnectionMillis: Double?
    public let requestMillis: Double?
    public let responseMillis: Double?

    init(_ metrics: URLSessionTaskMetrics) {
        transactionCount = metrics.transactionMetrics.count
        redirects = metrics.redirectCount
        if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) {
            requestBodyBytesSent = metrics.transactionMetrics.reduce(0) { $0 + $1.countOfRequestBodyBytesSent }
            responseBodyBytesReceived = metrics.transactionMetrics.reduce(0) { $0 + $1.countOfResponseBodyBytesReceived }
        } else {
            requestBodyBytesSent = 0
            responseBodyBytesReceived = 0
        }

        let transactions = metrics.transactionMetrics
        fetchStartMillis = Self.intervalMillis(
            start: transactions.compactMap(\.fetchStartDate).min(),
            end: transactions.compactMap(\.responseEndDate).max()
        )
        domainLookupMillis = Self.sumMillis(transactions, start: \.domainLookupStartDate, end: \.domainLookupEndDate)
        connectMillis = Self.sumMillis(transactions, start: \.connectStartDate, end: \.connectEndDate)
        secureConnectionMillis = Self.sumMillis(transactions, start: \.secureConnectionStartDate, end: \.secureConnectionEndDate)
        requestMillis = Self.sumMillis(transactions, start: \.requestStartDate, end: \.requestEndDate)
        responseMillis = Self.sumMillis(transactions, start: \.responseStartDate, end: \.responseEndDate)
    }

    private static func sumMillis(
        _ transactions: [URLSessionTaskTransactionMetrics],
        start: KeyPath<URLSessionTaskTransactionMetrics, Date?>,
        end: KeyPath<URLSessionTaskTransactionMetrics, Date?>
    ) -> Double? {
        let values = transactions.compactMap { intervalMillis(start: $0[keyPath: start], end: $0[keyPath: end]) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private static func intervalMillis(start: Date?, end: Date?) -> Double? {
        guard let start, let end else { return nil }
        return end.timeIntervalSince(start) * 1_000
    }
}

public enum APITelemetryRedactor {
    private static let sensitiveHeaderNames: Set<String> = [
        "authorization",
        "cookie",
        "set-cookie",
        "proxy-authorization",
        "x-api-key",
        "x-csrf-token",
        "x-xsrf-token",
    ]

    private static let sensitiveBodyKeyFragments = [
        "access_token",
        "refresh_token",
        "id_token",
        "token",
        "secret",
        "password",
        "authorization",
        "code",
        "verifier",
        "api_key",
        "apikey",
        "cookie",
    ]

    public static func headers(_ headers: [String: String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: headers.map { key, value in
            if sensitiveHeaderNames.contains(key.lowercased()) {
                return (key, "<redacted>")
            }
            return (key, value)
        })
    }

    public static func queryItems(_ items: [URLQueryItem]) -> [URLQueryItem] {
        items.map { item in
            guard isSensitiveKey(item.name) else { return item }
            return URLQueryItem(name: item.name, value: "<redacted>")
        }
    }

    public static func body(_ data: Data?, contentType: String?) -> Data? {
        guard let data, !data.isEmpty else { return data }
        let lowerContentType = contentType?.lowercased() ?? ""

        if lowerContentType.contains("json"),
           let object = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(object) {
            let redacted = redactJSON(object)
            return try? JSONSerialization.data(withJSONObject: redacted, options: [.sortedKeys])
        }

        if lowerContentType.contains("x-www-form-urlencoded"),
           let string = String(data: data, encoding: .utf8) {
            var components = URLComponents()
            components.queryItems = string
                .split(separator: "&")
                .map { pair in
                    let pieces = pair.split(separator: "=", maxSplits: 1).map(String.init)
                    let name = pieces.first?.removingPercentEncoding ?? ""
                    let value = pieces.count > 1 ? pieces[1].removingPercentEncoding : nil
                    return URLQueryItem(name: name, value: value)
                }
            components.queryItems = queryItems(components.queryItems ?? [])
            return components.percentEncodedQuery?.data(using: .utf8)
        }

        return data
    }

    public static func url(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.queryItems = queryItems(components.queryItems ?? [])
        return components.url ?? url
    }

    private static func redactJSON(_ object: Any) -> Any {
        if let dictionary = object as? [String: Any] {
            let redacted: [(String, Any)] = dictionary.map { key, value in
                if isSensitiveKey(key) {
                    return (key, "<redacted>")
                }
                return (key, redactJSON(value))
            }
            return Dictionary(uniqueKeysWithValues: redacted)
        }

        if let array = object as? [Any] {
            return array.map(redactJSON)
        }

        return object
    }

    private static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key.lowercased()
        return sensitiveBodyKeyFragments.contains { normalized.contains($0) }
    }
}

final class APITaskMetricsCollector: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var collectedMetrics: URLSessionTaskMetrics?

    var snapshot: APITaskMetrics? {
        lock.withLock {
            collectedMetrics.map(APITaskMetrics.init)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        lock.withLock {
            collectedMetrics = metrics
        }
    }
}
