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
        guard let fileName = task.taskDescription else { return }
        if error == nil, (task.response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false {
            let tmpURL = cacheURL(for: String(fileName.dropLast(5))) // strip .json
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }
}
