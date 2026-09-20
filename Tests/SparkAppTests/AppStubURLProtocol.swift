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
    private static let outgoingBodies = OutgoingBodies()

    /// Installs `handler` for every request to `host`, and clears anything
    /// previously recorded for it.
    static func set(host: String, _ handler: @escaping Handler) async {
        await storage.set(host: host, handler)
    }

    /// Requests made to `host` since its handler was installed, in order.
    static func recorded(host: String) async -> [URLRequest] {
        await storage.recorded(host: host)
    }

    /// How each recorded request's body was recovered, positionally matching
    /// `recorded(host:)`. Only useful in a failure message: URLSession has
    /// several ways of handing a body to a `URLProtocol` and this says which
    /// one, if any, produced the bytes.
    static func bodyDiagnostics(host: String) async -> [String] {
        await storage.diagnostics(host: host)
    }

    override class func canInit(with _: URLRequest) -> Bool { true }

    /// The URL loading system calls this with the request as the caller built
    /// it, before the body is moved out of `httpBody`. Keep a copy: by
    /// `startLoading()` it may be the only one left.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        if let body = request.httpBody, !body.isEmpty {
            outgoingBodies.stash(body, for: request)
        }
        return request
    }

    override func startLoading() {
        let (request, diagnostic) = Self.materializingBody(of: self.request, task: task)
        let client = self.client
        Task {
            let host = request.url?.host ?? ""
            await Self.storage.record(request, diagnostic: diagnostic, host: host)
            guard let handler = await Self.storage.handler(host: host) else {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
                return
            }
            let (data, status, headers) = await handler(request)
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
    }

    /// URLSession strips `httpBody` from the request it hands a `URLProtocol`,
    /// and which replacement it offers varies by release: a readable
    /// `httpBodyStream`, a bound pair that fills in asynchronously, a `task`
    /// holding the original request, or — on the iOS 27 simulator — none of
    /// them. Try each in turn so recorded requests (and handlers) see the body
    /// the way the caller set it, and report which one answered.
    private static func materializingBody(
        of request: URLRequest,
        task: URLSessionTask?
    ) -> (URLRequest, String) {
        if request.httpBody != nil { return (request, "httpBody") }

        var source = "none"
        var recovered: Data?

        if let stream = request.httpBodyStream {
            let drained = drain(stream)
            if !drained.isEmpty {
                recovered = drained
                source = "httpBodyStream"
            } else {
                source = "httpBodyStream (drained empty)"
            }
        }
        if recovered == nil, let body = task?.originalRequest?.httpBody ?? task?.currentRequest?.httpBody {
            recovered = body
            source = "task request"
        }
        if recovered == nil, let body = outgoingBodies.take(for: request) {
            recovered = body
            source = "canonicalRequest stash"
        }

        guard let body = recovered else {
            return (request, "unrecovered — \(source), stream: \(request.httpBodyStream == nil ? "nil" : "present"), task: \(task == nil ? "nil" : "present")")
        }
        var copy = request
        copy.httpBody = body
        copy.httpBodyStream = nil
        return (copy, source)
    }

    /// Reads a body stream to its end. A stream URLSession fills in
    /// asynchronously has no bytes ready at first, so wait for them rather
    /// than reporting an empty body — but only briefly, so a stream that never
    /// delivers fails the test instead of hanging the suite.
    private static func drain(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            guard stream.hasBytesAvailable else {
                switch stream.streamStatus {
                case .atEnd, .closed, .error: return data
                default: Thread.sleep(forTimeInterval: 0.005)
                }
                continue
            }
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    // Deliberately empty. Cancelling the delivery task here (tracked, guarded
    // by Task.isCancelled) was tried and reverted: URLSession calls
    // stopLoading() during ordinary teardown, which cancelled in-flight
    // responses and made concurrent fetches — preloadDigests' task group —
    // silently return nil. A late response in a test is harmless; a dropped
    // one quietly inverts what the test asserts.
    override func stopLoading() {}

    /// Bodies seen by `canonicalRequest(for:)`, queued per method-and-URL and
    /// taken in order by `startLoading()`. `canonicalRequest` is a class method
    /// with no test context to hang onto, hence the process-wide store; the
    /// queue is capped so a request that never loads cannot grow it forever.
    private final class OutgoingBodies: @unchecked Sendable {
        private let lock = NSLock()
        private var queues: [String: [Data]] = [:]
        private static let limit = 32

        func stash(_ body: Data, for request: URLRequest) {
            lock.withLock {
                var queue = queues[Self.key(request), default: []]
                queue.append(body)
                if queue.count > Self.limit { queue.removeFirst(queue.count - Self.limit) }
                queues[Self.key(request)] = queue
            }
        }

        func take(for request: URLRequest) -> Data? {
            lock.withLock {
                guard var queue = queues[Self.key(request)], !queue.isEmpty else { return nil }
                let body = queue.removeFirst()
                queues[Self.key(request)] = queue
                return body
            }
        }

        private static func key(_ request: URLRequest) -> String {
            "\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")"
        }
    }

    private actor Storage {
        private var handlers: [String: Handler] = [:]
        private var requests: [String: [URLRequest]] = [:]
        private var bodyDiagnostics: [String: [String]] = [:]

        func set(host: String, _ handler: @escaping Handler) {
            handlers[host] = handler
            requests[host] = []
            bodyDiagnostics[host] = []
        }

        func handler(host: String) -> Handler? { handlers[host] }

        func record(_ request: URLRequest, diagnostic: String, host: String) {
            requests[host, default: []].append(request)
            bodyDiagnostics[host, default: []].append(diagnostic)
        }

        func recorded(host: String) -> [URLRequest] { requests[host] ?? [] }
        func diagnostics(host: String) -> [String] { bodyDiagnostics[host] ?? [] }
    }
}
