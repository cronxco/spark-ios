import Foundation

/// URLProtocol shim that lets tests answer requests from an async closure while
/// keeping a record of everything that flew past, so assertions can live in
/// the test body rather than inside the handler (which runs on a detached task
/// where swift-testing can't associate failures with the current test).
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async -> (Data, Int, [String: String])

    private static let storage = HandlerStorage()

    static func set(_ handler: @escaping Handler) async {
        await storage.set(handler)
    }

    /// Snapshot of every request the protocol has handled since the last
    /// `set(_:)` call. Use after awaiting the request under test.
    static func recorded() async -> [URLRequest] {
        await storage.recorded()
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let request = self.request
        let client = self.client
        Task {
            await Self.storage.record(request)
            guard let handler = await Self.storage.handler() else {
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

    override func stopLoading() {}

    private actor HandlerStorage {
        private var current: Handler?
        private var requests: [URLRequest] = []

        func set(_ handler: @escaping Handler) {
            current = handler
            requests.removeAll()
        }

        func handler() -> Handler? { current }
        func record(_ request: URLRequest) { requests.append(request) }
        func recorded() -> [URLRequest] { requests }
    }
}
