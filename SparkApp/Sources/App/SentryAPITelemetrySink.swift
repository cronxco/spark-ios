import Foundation
import Sentry
import SparkKit

final class SentryAPITelemetrySink: APITelemetrySink, @unchecked Sendable {
    private let maxBodyCharacters = 100_000

    func capture(_ event: APITelemetryEvent) async {
        addBreadcrumb(for: event)
        captureTransaction(for: event)

        guard event.outcome != .success, event.outcome != .notModified else { return }

        let message = "API \(event.outcome.sentryName): \(event.method) \(event.url.host() ?? "")\(event.url.path)"
        SentrySDK.capture(message: message) { scope in
            scope.setTag(value: event.outcome.sentryName, key: "api.outcome")
            scope.setTag(value: event.method, key: "http.method")
            scope.setTag(value: event.url.host() ?? "unknown", key: "http.host")
            if let statusCode = event.statusCode {
                scope.setTag(value: String(statusCode), key: "http.status_code")
            }
            scope.setContext(value: self.context(for: event), key: "api")
        }
    }

    private func addBreadcrumb(for event: APITelemetryEvent) {
        let level: SentryLevel = switch event.outcome {
        case .success, .notModified: .info
        case .unauthorized, .httpError, .transportError, .decodingError, .noData: .error
        }

        let crumb = Breadcrumb(level: level, category: "api")
        crumb.type = "http"
        crumb.message = "\(event.method) \(event.url.path) \(event.statusCode.map(String.init) ?? event.outcome.sentryName)"
        crumb.data = breadcrumbData(for: event)
        SentrySDK.addBreadcrumb(crumb)
    }

    private func captureTransaction(for event: APITelemetryEvent) {
        let name = "\(event.method) \(event.endpointPath ?? event.url.path)"
        let transaction = SentrySDK.startTransaction(name: name, operation: event.operation)
        transaction.startTimestamp = Date(timeIntervalSinceNow: -(event.durationMillis / 1_000))
        transaction.setTag(value: event.outcome.sentryName, key: "api.outcome")
        transaction.setTag(value: event.method, key: "http.method")
        transaction.setTag(value: event.url.host() ?? "unknown", key: "http.host")
        transaction.setData(value: event.url.path, key: "http.path")
        transaction.setData(value: event.url.query ?? "", key: "http.query")
        transaction.setData(value: event.statusCode as Any, key: "http.status_code")
        transaction.setData(value: event.responseSizeBytes, key: "http.response_content_length")
        transaction.setData(value: event.attempt, key: "spark.api.attempt")
        transaction.setData(value: event.isRefreshRequest, key: "spark.api.is_refresh_request")
        transaction.setMeasurement(name: "http.client.duration", value: NSNumber(value: event.durationMillis))
        if let decodeDurationMillis = event.decodeDurationMillis {
            transaction.setMeasurement(name: "spark.api.decode_duration", value: NSNumber(value: decodeDurationMillis))
        }
        if let metrics = event.metrics {
            transaction.setData(value: metrics.requestBodyBytesSent, key: "http.request_body_bytes_sent")
            transaction.setData(value: metrics.responseBodyBytesReceived, key: "http.response_body_bytes_received")
            transaction.setData(value: metrics.transactionCount, key: "http.transaction_count")
            transaction.setData(value: metrics.redirects, key: "http.redirect_count")
            transaction.setMeasurement(name: "http.fetch", value: number(metrics.fetchStartMillis))
            transaction.setMeasurement(name: "http.dns", value: number(metrics.domainLookupMillis))
            transaction.setMeasurement(name: "http.connect", value: number(metrics.connectMillis))
            transaction.setMeasurement(name: "http.tls", value: number(metrics.secureConnectionMillis))
            transaction.setMeasurement(name: "http.request", value: number(metrics.requestMillis))
            transaction.setMeasurement(name: "http.response", value: number(metrics.responseMillis))
        }
        transaction.finish()
    }

    private func breadcrumbData(for event: APITelemetryEvent) -> [String: Any] {
        [
            "id": event.id.uuidString,
            "method": event.method,
            "url": event.url.absoluteString,
            "status_code": event.statusCode as Any,
            "outcome": event.outcome.sentryName,
            "duration_ms": event.durationMillis,
            "response_size_bytes": event.responseSizeBytes,
            "attempt": event.attempt,
            "is_refresh_request": event.isRefreshRequest,
        ]
    }

    private func context(for event: APITelemetryEvent) -> [String: Any] {
        var context: [String: Any] = breadcrumbData(for: event)
        context["endpoint_path"] = event.endpointPath as Any
        context["requires_auth"] = event.requiresAuth
        context["request_headers"] = event.requestHeaders
        context["response_headers"] = event.responseHeaders
        context["request_body"] = bodyString(event.requestBody)
        context["response_body"] = bodyString(event.responseBody)
        context["decode_duration_ms"] = event.decodeDurationMillis as Any
        context["error"] = event.errorDescription as Any

        if let metrics = event.metrics {
            context["metrics"] = [
                "transaction_count": metrics.transactionCount,
                "redirects": metrics.redirects,
                "request_body_bytes_sent": metrics.requestBodyBytesSent,
                "response_body_bytes_received": metrics.responseBodyBytesReceived,
                "fetch_ms": metrics.fetchStartMillis as Any,
                "dns_ms": metrics.domainLookupMillis as Any,
                "connect_ms": metrics.connectMillis as Any,
                "tls_ms": metrics.secureConnectionMillis as Any,
                "request_ms": metrics.requestMillis as Any,
                "response_ms": metrics.responseMillis as Any,
            ]
        }

        return context
    }

    private func bodyString(_ data: Data?) -> String? {
        guard let data, !data.isEmpty else { return data == nil ? nil : "" }

        let raw = String(data: data, encoding: .utf8) ?? data.base64EncodedString()
        if raw.count <= maxBodyCharacters {
            return raw
        }
        let index = raw.index(raw.startIndex, offsetBy: maxBodyCharacters)
        return String(raw[..<index]) + "\n<truncated \(raw.count - maxBodyCharacters) characters>"
    }

    private func number(_ value: Double?) -> NSNumber {
        NSNumber(value: value ?? 0)
    }
}

private extension APITelemetryEvent.Outcome {
    var sentryName: String {
        switch self {
        case .success: "success"
        case .notModified: "not_modified"
        case .unauthorized: "unauthorized"
        case .httpError: "http_error"
        case .transportError: "transport_error"
        case .decodingError: "decoding_error"
        case .noData: "no_data"
        }
    }
}
