import Foundation

/// Stubs out `URLSession` for app-level tests, so a view model can be driven
/// through its real `APIClient` rather than a hand-rolled double.
///
/// Handlers and recorded requests are keyed by host. `URLProtocol` registration
/// is process-wide and swift-testing runs suites in parallel, so two suites
/// stubbing at once would otherwise overwrite each other's handler and clear
/// each other's recordings mid-test. Give each suite its own host.
final class AppStubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async -> (Data, Int, [String: String])

    private static let storage = Storage()

    /// Installs `handler` for every request to `host`, and clears anything
    /// previously recorded for it.
    static func set(host: String, _ handler: @escaping Handler) async {
        await storage.set(host: host, handler)
    }

    /// Requests made to `host` since its handler was installed, in order.
    static func recorded(host: String) async -> [URLRequest] {
        await storage.recorded(host: host)
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    /// The in-flight load, so `stopLoading()` can cancel it.
    ///
    /// `startLoading()` answers asynchronously (the handler is async), so a
    /// cancelled request — a timeout, or `URLSession` tearing the task down —
    /// would otherwise still deliver a response to a client that has moved on.
    /// URLSession calls `startLoading`/`stopLoading` on its own loading thread,
    /// hence the lock rather than bare mutable state on an `@unchecked Sendable`.
    private let lock = NSLock()
    private var loadTask: Task<Void, Never>?

    override func startLoading() {
        let request = self.request
        let client = self.client
        let task = Task {
            let host = request.url?.host ?? ""
            await Self.storage.record(request, host: host)
            guard !Task.isCancelled else { return }
            guard let handler = await Self.storage.handler(host: host) else {
                guard !Task.isCancelled else { return }
                client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
                return
            }
            let (data, status, headers) = await handler(request)
            guard !Task.isCancelled else { return }
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "about:blank")!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
        lock.withLock { loadTask = task }
    }

    override func stopLoading() {
        let task = lock.withLock {
            let task = loadTask
            loadTask = nil
            return task
        }
        task?.cancel()
    }

    private actor Storage {
        private var handlers: [String: Handler] = [:]
        private var requests: [String: [URLRequest]] = [:]

        func set(host: String, _ handler: @escaping Handler) {
            handlers[host] = handler
            requests[host] = []
        }

        func handler(host: String) -> Handler? { handlers[host] }
        func record(_ request: URLRequest, host: String) { requests[host, default: []].append(request) }
        func recorded(host: String) -> [URLRequest] { requests[host] ?? [] }
    }
}
