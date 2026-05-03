import Foundation
import SparkKit

/// Uploads HealthKit samples to the backend via a background URLSession.
/// Persists pending batches to App Group caches so uploads survive termination.
public final class HealthSampleUploader: NSObject, @unchecked Sendable {
    public static let shared = HealthSampleUploader()

    private static let sessionIdentifier = "co.cronx.spark.health-upload"
    private static let suiteName = "group.co.cronx.spark"

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private let lock = NSLock()
    private var completionHandlers: [String: @Sendable () -> Void] = [:]
    private var telemetryByTaskIdentifier: [Int: PendingTelemetry] = [:]
    private var environment: APIEnvironment = .current()
    private var accessToken: String?

    private override init() { super.init() }

    // MARK: - Public API

    public func configure(environment: APIEnvironment, accessToken: String?) {
        lock.withLock {
            self.environment = environment
            self.accessToken = accessToken
        }
    }

    public func addCompletionHandler(_ handler: @escaping @Sendable () -> Void, for identifier: String) {
        guard identifier == Self.sessionIdentifier else { return }
        lock.withLock { completionHandlers[identifier] = handler }
        _ = session // Force lazy init to reconnect to the existing background session
    }

    public func upload(samples: [HealthSample]) {
        guard !samples.isEmpty else { return }
        let env = lock.withLock { environment }
        let token = lock.withLock { accessToken }

        let batch = HealthSampleBatch(samples: samples)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let body = try? encoder.encode(batch) else { return }

        // Background URLSession requires a file-based body.
        let tmpURL = cacheURL(for: UUID().uuidString)
        do {
            try body.write(to: tmpURL)
        } catch { return }

        guard var components = URLComponents(url: env.baseURL, resolvingAgainstBaseURL: false) else { return }
        components.path = joinedPath(basePath: components.path, endpointPath: "/health/samples")
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let task = session.uploadTask(with: request, fromFile: tmpURL)
        task.taskDescription = tmpURL.lastPathComponent
        let pending = PendingTelemetry(
            startedAt: Date(),
            request: request,
            body: body,
            fileSizeBytes: body.count
        )
        lock.withLock { telemetryByTaskIdentifier[task.taskIdentifier] = pending }
        task.resume()
    }

    // MARK: - Private

    private func cacheURL(for name: String) -> URL {
        let dir = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.suiteName)?
            .appendingPathComponent("Caches/health_uploads", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(name).json")
    }

    private func joinedPath(basePath: String, endpointPath: String) -> String {
        let base = basePath == "/" ? "" : basePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpoint = endpointPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return base.isEmpty ? "/\(endpoint)" : "/\(base)/\(endpoint)"
    }
}

private struct PendingTelemetry: Sendable {
    let startedAt: Date
    let request: URLRequest
    let body: Data
    let fileSizeBytes: Int
}

// MARK: - URLSessionDelegate

extension HealthSampleUploader: URLSessionDelegate, URLSessionTaskDelegate {
    nonisolated public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let handlers = lock.withLock { completionHandlers }
        for handler in handlers.values {
            DispatchQueue.main.async { handler() }
        }
        lock.withLock { completionHandlers.removeAll() }
    }

    nonisolated public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let pending = lock.withLock {
            telemetryByTaskIdentifier.removeValue(forKey: task.taskIdentifier)
        }
        if let pending {
            let response = task.response as? HTTPURLResponse
            Task {
                await APITelemetry.shared.capture(
                    APITelemetryEvent(
                        operation: "http.client.background_upload",
                        method: pending.request.httpMethod ?? "POST",
                        url: APITelemetryRedactor.url(pending.request.url ?? URL(string: "about:blank")!),
                        endpointPath: "/health/samples",
                        requiresAuth: true,
                        requestHeaders: APITelemetryRedactor.headers(pending.request.allHTTPHeaderFields ?? [:]),
                        requestBody: APITelemetryRedactor.body(pending.body, contentType: pending.request.value(forHTTPHeaderField: "Content-Type")),
                        statusCode: response?.statusCode,
                        responseHeaders: APITelemetryRedactor.headers(response?.stringHeaderFields ?? [:]),
                        responseBody: nil,
                        responseSizeBytes: pending.fileSizeBytes,
                        durationMillis: Date().timeIntervalSince(pending.startedAt) * 1_000,
                        outcome: Self.outcome(response: response, error: error),
                        errorDescription: error.map { String(describing: $0) }
                    )
                )
            }
        }

        guard let fileName = task.taskDescription else { return }
        if error == nil, (task.response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false {
            let tmpURL = cacheURL(for: String(fileName.dropLast(5))) // strip .json
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }

    private nonisolated static func outcome(
        response: HTTPURLResponse?,
        error: Error?
    ) -> APITelemetryEvent.Outcome {
        if error != nil { return .transportError }
        guard let response else { return .noData }
        if (200..<300).contains(response.statusCode) { return .success }
        if response.statusCode == 401 { return .unauthorized }
        if response.statusCode == 304 { return .notModified }
        return .httpError
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
