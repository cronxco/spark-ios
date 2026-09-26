import Foundation
import SparkKit

/// Uploads HealthKit samples to the backend via a background URLSession.
/// Persists pending batches to App Group caches so uploads survive termination.
public final class HealthSampleUploader: NSObject, @unchecked Sendable {
    public static let shared = HealthSampleUploader()

    private static let sessionIdentifier = "co.cronx.sparkapp.health-upload"
    private static let suiteName = "group.co.cronx.sparkapp"

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private let lock = NSLock()
    private var completionHandlers: [String: @Sendable () -> Void] = [:]
    private var telemetryByTaskIdentifier: [Int: PendingTelemetry] = [:]
    /// Uploads whose caller is waiting to hear that every batch was accepted.
    private var groups: [UUID: UploadGroup] = [:]
    private var groupByTaskIdentifier: [Int: UUID] = [:]
    #if DEBUG
    private var captures: [Int: APISessionStore.Ticket] = [:]
    #endif
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

    /// Uploads in batches of at most `HealthSample.maxBatchSize`, the most the
    /// server accepts; a larger request is rejected whole.
    ///
    /// `completion` hears `true` once every batch has come back 2xx, and
    /// `false` as soon as the last batch finishes if any did not. It is not
    /// called if the app is terminated before the uploads finish — the caller
    /// should treat silence as "not delivered".
    public func upload(samples: [HealthSample], completion: (@Sendable (Bool) -> Void)? = nil) {
        let batches = HealthSampleBatch.batches(of: samples)
        var group: UUID?
        if let completion {
            guard !batches.isEmpty else {
                completion(true)
                return
            }
            let id = UUID()
            lock.withLock { groups[id] = UploadGroup(remaining: batches.count, delivered: true, completion: completion) }
            group = id
        }

        for batch in batches {
            upload(batch: batch, group: group)
        }
    }

    // MARK: - Private

    private func upload(batch: HealthSampleBatch, group: UUID?) {
        let env = lock.withLock { environment }
        let token = lock.withLock { accessToken }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let body = try? encoder.encode(batch) else {
            finish(group: group, delivered: false)
            return
        }

        // Background URLSession requires a file-based body.
        let tmpURL = cacheURL(for: UUID().uuidString)
        do {
            try body.write(to: tmpURL)
        } catch {
            finish(group: group, delivered: false)
            return
        }

        guard var components = URLComponents(url: env.baseURL, resolvingAgainstBaseURL: false) else {
            finish(group: group, delivered: false)
            return
        }
        components.path = joinedPath(basePath: components.path, endpointPath: "/health/samples")
        guard let url = components.url else {
            finish(group: group, delivered: false)
            return
        }

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
        lock.withLock {
            telemetryByTaskIdentifier[task.taskIdentifier] = pending
            if let group { groupByTaskIdentifier[task.taskIdentifier] = group }
        }
        #if DEBUG
        let capture = APISessionStore.shared.begin(request)
        lock.withLock { captures[task.taskIdentifier] = capture }
        #endif
        task.resume()
    }

    /// Records one batch's outcome and, once the group's last batch is in,
    /// tells the caller whether all of them were delivered.
    private func finish(group: UUID?, delivered: Bool) {
        guard let group else { return }
        let outcome: (completion: @Sendable (Bool) -> Void, delivered: Bool)? = lock.withLock {
            guard var entry = groups[group] else { return nil }
            entry.remaining -= 1
            entry.delivered = entry.delivered && delivered
            guard entry.remaining == 0 else {
                groups[group] = entry
                return nil
            }
            groups[group] = nil
            return (entry.completion, entry.delivered)
        }
        if let outcome {
            outcome.completion(outcome.delivered)
        }
    }

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

private struct UploadGroup {
    var remaining: Int
    var delivered: Bool
    let completion: @Sendable (Bool) -> Void
}

private struct PendingTelemetry: Sendable {
    let startedAt: Date
    let request: URLRequest
    let body: Data
    let fileSizeBytes: Int
}

// MARK: - URLSessionDelegate

extension HealthSampleUploader: URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    #if DEBUG
    nonisolated public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let capture = lock.withLock({ captures[dataTask.taskIdentifier] }) {
            APISessionStore.shared.response(capture, status: (dataTask.response as? HTTPURLResponse)?.statusCode, data: data, append: true)
        }
    }
    #endif
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
        #if DEBUG
        if let capture = lock.withLock({ captures.removeValue(forKey: task.taskIdentifier) }) {
            let status = (task.response as? HTTPURLResponse)?.statusCode
            let outcome = error.map { $0.isAPICancellation ? "cancelled" : "transport failure" }
                ?? (status == 304 ? "not modified" : status.map { (200..<300).contains($0) ? "success" : "HTTP failure" } ?? "invalid response")
            APISessionStore.shared.finish(capture, outcome: outcome, status: status)
        }
        #endif
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

        let delivered = error == nil
            && (task.response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false
        let group = lock.withLock { groupByTaskIdentifier.removeValue(forKey: task.taskIdentifier) }
        finish(group: group, delivered: delivered)

        guard let fileName = task.taskDescription else { return }
        if delivered {
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
