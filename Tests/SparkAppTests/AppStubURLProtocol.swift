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
    private static let bodyKeyHeader = "X-AppStub-Body-Key"

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
    /// `startLoading()` it may be the only one left. The copy is keyed by a
    /// header stamped on the canonical request, so each load takes back its
    /// own body rather than one that merely shares a method and URL.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        guard let body = request.httpBody, !body.isEmpty,
              request.value(forHTTPHeaderField: bodyKeyHeader) == nil
        else { return request }

        let key = UUID().uuidString
        outgoingBodies.stash(body, key: key)
        var stamped = request
        stamped.setValue(key, forHTTPHeaderField: bodyKeyHeader)
        return stamped
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
        of original: URLRequest,
        task: URLSessionTask?
    ) -> (URLRequest, String) {
        var request = original
        // Take the stashed body whichever source ends up supplying one, and
        // drop the stub's own header again: a body left in the store could
        // otherwise attach itself to some later request, and the header is
        // plumbing no test should have to look past.
        let key = request.value(forHTTPHeaderField: bodyKeyHeader)
        let stashed = key.flatMap { outgoingBodies.take(key: $0) }
        if key != nil { request.setValue(nil, forHTTPHeaderField: bodyKeyHeader) }

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
        if recovered == nil, let body = stashed {
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

    /// Bodies seen by `canonicalRequest(for:)`, each under the key stamped on
    /// its request. `canonicalRequest` is a class method with no test context
    /// to hang onto, hence the process-wide store; it is capped so requests
    /// that are never loaded cannot grow it forever.
    private final class OutgoingBodies: @unchecked Sendable {
        private let lock = NSLock()
        private var bodies: [String: Data] = [:]
        private var order: [String] = []
        private static let limit = 64

        func stash(_ body: Data, key: String) {
            lock.withLock {
                bodies[key] = body
                order.append(key)
                while order.count > Self.limit {
                    bodies.removeValue(forKey: order.removeFirst())
                }
            }
        }

        func take(key: String) -> Data? {
            lock.withLock {
                guard let body = bodies.removeValue(forKey: key) else { return nil }
                order.removeAll { $0 == key }
                return body
            }
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
