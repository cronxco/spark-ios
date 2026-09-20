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

    override func startLoading() {
        let request = Self.materializingBody(of: self.request, task: task)
        let client = self.client
        Task {
            let host = request.url?.host ?? ""
            await Self.storage.record(request, host: host)
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

    /// URLSession strips `httpBody` from the request it hands a `URLProtocol`.
    /// It usually leaves the bytes behind in `httpBodyStream`, but not always —
    /// on the iOS 27 simulator a POST arrives with neither, which is what made
    /// the Flint notes tests fail on `#require(request.httpBody)`. Take the
    /// stream when there is one and fall back to the task's own copy of the
    /// request, which is the `URLRequest` the caller handed to `URLSession`
    /// and still carries the body. Either way, recorded requests (and
    /// handlers) see the body the way the caller set it.
    private static func materializingBody(of request: URLRequest, task: URLSessionTask?) -> URLRequest {
        guard request.httpBody == nil else { return request }

        var recovered: Data?
        if let stream = request.httpBodyStream {
            let drained = Self.drain(stream)
            recovered = drained.isEmpty ? nil : drained
        }
        if recovered == nil {
            recovered = task?.originalRequest?.httpBody ?? task?.currentRequest?.httpBody
        }

        guard let body = recovered else { return request }
        var copy = request
        copy.httpBody = body
        copy.httpBodyStream = nil
        return copy
    }

    private static func drain(_ stream: InputStream) -> Data {
        var data = Data()
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
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
