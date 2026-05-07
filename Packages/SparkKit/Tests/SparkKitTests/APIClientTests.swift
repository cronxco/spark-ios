import Foundation
import Testing
@testable import SparkKit

@Suite("APIClient", .serialized)
struct APIClientTests {
    private func makeStore() -> KeychainTokenStore {
        let service = "co.cronx.sparkapp.tests.api.\(UUID().uuidString)"
        return KeychainTokenStore(service: service, account: "test", accessGroup: nil)
    }

    private func makeCache() -> ETagCache {
        let suite = "spark.etag.apiclient.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ETagCache(defaults: defaults)
    }

    private func makeSession(protocolClasses: [AnyClass] = [StubURLProtocol.self]) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = protocolClasses
        return URLSession(configuration: config)
    }

    private func makeClient(
        environment: APIEnvironment = .init(
            baseURL: URL(string: "https://test.spark.cronx.co/api/v1/mobile")!,
            oauthAuthorizeURL: URL(string: "https://test.spark.cronx.co/oauth/authorize")!,
            name: "test"
        ),
        telemetry: APITelemetry = APITelemetry(),
        session: URLSession? = nil,
        tokenStore: KeychainTokenStore? = nil
    ) -> (APIClient, KeychainTokenStore) {
        let tokenStore = tokenStore ?? makeStore()
        let client = APIClient(
            environment: environment,
            session: session ?? makeSession(),
            tokenStore: tokenStore,
            etagCache: makeCache(),
            telemetry: telemetry
        )
        return (client, tokenStore)
    }

    @Test("200 decodes response body + records ETag + sends Bearer")
    func happyPath() async throws {
        let (client, tokenStore) = makeClient()
        await tokenStore.store(access: "a", refresh: "r", expiresIn: 3600)

        await StubURLProtocol.set { _ in
            let payload = """
            {
              "date": "2026-04-19",
              "timezone": "Europe/London",
              "sync_status": {"in_flight": false, "last_synced_at": null, "anomaly_count": 0},
              "sections": {},
              "anomalies": []
            }
            """.data(using: .utf8)!
            return (payload, 200, ["ETag": "\"etag-abc\""])
        }

        let summary = try await client.request(BriefingEndpoint.today())
        #expect(summary.date == "2026-04-19")
        #expect(summary.timezone == "Europe/London")

        let captured = await StubURLProtocol.recorded()
        let briefingRequest = try #require(captured.first { $0.url?.path == "/api/v1/mobile/briefing/today" })
        #expect(briefingRequest.value(forHTTPHeaderField: "Authorization") == "Bearer a")
    }

    @Test("304 is surfaced as APIError.notModified")
    func notModified() async throws {
        let (client, _) = makeClient()
        await StubURLProtocol.set { _ in (Data(), 304, [:]) }
        await #expect(throws: APIError.self) {
            _ = try await client.request(BriefingEndpoint.today())
        }
    }

    @Test("401 with refresh token refreshes and retries once")
    func refreshThenRetry() async throws {
        let (client, tokenStore) = makeClient()
        await tokenStore.store(access: "old", refresh: "r-1", expiresIn: 60)

        actor Counter { var count = 0; func bump() -> Int { count += 1; return count } }
        let counter = Counter()

        await StubURLProtocol.set { request in
            let hit = await counter.bump()
            if request.url?.path.hasSuffix("/oauth/refresh") == true {
                let json = """
                {"token_type":"Bearer","access_token":"new","refresh_token":"r-2","expires_in":3600}
                """.data(using: .utf8)!
                return (json, 200, [:])
            }
            if hit == 1 {
                return (Data(), 401, [:])
            }
            let payload = """
            {"date":"2026-04-19","timezone":"UTC","sync_status":{"in_flight":false,"last_synced_at":null,"anomaly_count":0},"sections":{},"anomalies":[]}
            """.data(using: .utf8)!
            return (payload, 200, [:])
        }

        let summary = try await client.request(BriefingEndpoint.today())
        #expect(summary.date == "2026-04-19")
        #expect(await tokenStore.accessToken() == "new")

        let captured = await StubURLProtocol.recorded()
        let retryRequest = captured.last { $0.url?.path == "/api/v1/mobile/briefing/today" }
        #expect(retryRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer new")
    }

    @Test("concurrent 401s share one refresh request")
    func concurrentUnauthorizedRequestsShareRefresh() async throws {
        let (client, tokenStore) = makeClient()
        await tokenStore.store(access: "old", refresh: "r-1", expiresIn: 60)

        actor Stats {
            private(set) var refreshCount = 0
            private(set) var protectedAuthorizations: [String?] = []

            func recordRefresh() -> Int {
                refreshCount += 1
                return refreshCount
            }

            func recordProtected(_ authorization: String?) {
                protectedAuthorizations.append(authorization)
            }
        }
        let stats = Stats()

        await StubURLProtocol.set { request in
            if request.url?.path.hasSuffix("/oauth/refresh") == true {
                _ = await stats.recordRefresh()
                try? await Task.sleep(nanoseconds: 100_000_000)
                let json = """
                {"token_type":"Bearer","access_token":"new","refresh_token":"r-2","expires_in":3600}
                """.data(using: .utf8)!
                return (json, 200, [:])
            }

            await stats.recordProtected(request.value(forHTTPHeaderField: "Authorization"))
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer old" {
                return (Data(), 401, [:])
            }

            let payload = """
            {"date":"2026-04-19","timezone":"UTC","sync_status":{"in_flight":false,"last_synced_at":null,"anomaly_count":0},"sections":{},"anomalies":[]}
            """.data(using: .utf8)!
            return (payload, 200, [:])
        }

        let dates = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await client.request(BriefingEndpoint.today()).date
                }
            }

            var dates: [String] = []
            for try await date in group {
                dates.append(date)
            }
            return dates
        }

        #expect(dates == Array(repeating: "2026-04-19", count: 5))
        #expect(await tokenStore.accessToken() == "new")
        #expect(await tokenStore.refreshToken() == "r-2")
        #expect(await stats.refreshCount == 1)

        let protectedAuthorizations = await stats.protectedAuthorizations
        #expect(protectedAuthorizations.filter { $0 == "Bearer old" }.count == 5)
        #expect(protectedAuthorizations.filter { $0 == "Bearer new" }.count == 5)
    }

    @Test("concurrent 401s across clients share one refresh request")
    func concurrentUnauthorizedRequestsAcrossClientsShareRefresh() async throws {
        let tokenStore = makeStore()
        await tokenStore.store(access: "old", refresh: "r-1", expiresIn: 60)
        let (clientA, _) = makeClient(tokenStore: tokenStore)
        let (clientB, _) = makeClient(tokenStore: tokenStore)

        actor Stats {
            private(set) var refreshCount = 0
            private(set) var protectedAuthorizations: [String?] = []

            func recordRefresh() {
                refreshCount += 1
            }

            func recordProtected(_ authorization: String?) {
                protectedAuthorizations.append(authorization)
            }
        }
        let stats = Stats()

        await StubURLProtocol.set { request in
            if request.url?.path.hasSuffix("/oauth/refresh") == true {
                await stats.recordRefresh()
                try? await Task.sleep(nanoseconds: 100_000_000)
                let json = """
                {"token_type":"Bearer","access_token":"new","refresh_token":"r-2","expires_in":3600}
                """.data(using: .utf8)!
                return (json, 200, [:])
            }

            await stats.recordProtected(request.value(forHTTPHeaderField: "Authorization"))
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer old" {
                return (Data(), 401, [:])
            }

            let payload = """
            {"date":"2026-04-19","timezone":"UTC","sync_status":{"in_flight":false,"last_synced_at":null,"anomaly_count":0},"sections":{},"anomalies":[]}
            """.data(using: .utf8)!
            return (payload, 200, [:])
        }

        let dates = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await clientA.request(BriefingEndpoint.today()).date }
            group.addTask { try await clientB.request(BriefingEndpoint.today()).date }

            var dates: [String] = []
            for try await date in group {
                dates.append(date)
            }
            return dates
        }

        #expect(dates.sorted() == ["2026-04-19", "2026-04-19"])
        #expect(await tokenStore.accessToken() == "new")
        #expect(await tokenStore.refreshToken() == "r-2")
        #expect(await stats.refreshCount == 1)

        let protectedAuthorizations = await stats.protectedAuthorizations
        #expect(protectedAuthorizations.filter { $0 == "Bearer old" }.count == 2)
        #expect(protectedAuthorizations.filter { $0 == "Bearer new" }.count == 2)
    }

    @Test("failed refresh clears stored tokens")
    func failedRefreshClearsTokens() async {
        let (client, tokenStore) = makeClient()
        await tokenStore.store(access: "old", refresh: "r-1", expiresIn: 60)

        await StubURLProtocol.set { request in
            if request.url?.path.hasSuffix("/oauth/refresh") == true {
                return (
                    Data(#"{"error":"invalid_grant","error_description":"Refresh token already used; all device tokens revoked."}"#.utf8),
                    401,
                    ["Content-Type": "application/json"]
                )
            }
            return (Data(), 401, [:])
        }

        await #expect(throws: APIError.self) {
            _ = try await client.request(BriefingEndpoint.today())
        }

        #expect(await tokenStore.accessToken() == nil)
        #expect(await tokenStore.refreshToken() == nil)
    }

    @Test("stale failed refresh does not clear newer stored tokens")
    func staleFailedRefreshDoesNotClearNewerStoredTokens() async {
        let (client, tokenStore) = makeClient()
        await tokenStore.store(access: "old", refresh: "r-1", expiresIn: 60)

        await StubURLProtocol.set { request in
            if request.url?.path.hasSuffix("/oauth/refresh") == true {
                await tokenStore.store(access: "new", refresh: "r-2", expiresIn: 3600)
                return (
                    Data(#"{"error":"invalid_grant","error_description":"Refresh token already used."}"#.utf8),
                    401,
                    ["Content-Type": "application/json"]
                )
            }
            return (Data(), 401, [:])
        }

        await #expect(throws: APIError.self) {
            _ = try await client.request(BriefingEndpoint.today())
        }

        #expect(await tokenStore.accessToken() == "new")
        #expect(await tokenStore.refreshToken() == "r-2")
    }

    @Test("401 without refresh token surfaces .unauthorized")
    func unauthorizedWithoutRefresh() async {
        let (client, _) = makeClient()
        await StubURLProtocol.set { _ in (Data(), 401, [:]) }
        await #expect(throws: APIError.self) {
            _ = try await client.request(BriefingEndpoint.today())
        }
    }

    @Test("500 surfaces .httpStatus with status + body")
    func httpError() async {
        let (client, tokenStore) = makeClient()
        await tokenStore.store(access: "a", refresh: "r", expiresIn: 60)
        await StubURLProtocol.set { _ in (Data("oops".utf8), 500, [:]) }
        await #expect(throws: APIError.self) {
            _ = try await client.request(BriefingEndpoint.today())
        }
    }

    @Test("site-root requests do not include a double slash")
    func siteRootPathIsNormalized() async throws {
        let (client, _) = makeClient()
        await StubURLProtocol.set { _ in
            let payload = """
            {"token_type":"Bearer","access_token":"new","refresh_token":"r-2","expires_in":3600}
            """.data(using: .utf8)!
            return (payload, 200, [:])
        }

        _ = try await client.requestSiteRoot(AuthEndpoint.exchange(code: "abc", verifier: "verifier"))

        let captured = await StubURLProtocol.recorded()
        let request = try #require(captured.first)
        #expect(request.url?.path == "/oauth/token")
    }

    @Test("site-root requests use oauth host when base URL has a trailing slash")
    func siteRootUsesOAuthHost() async throws {
        let environment = APIEnvironment(
            baseURL: URL(string: "https://api.spark.cronx.co/api/v1/mobile/")!,
            oauthAuthorizeURL: URL(string: "https://auth.spark.cronx.co/oauth/authorize")!,
            name: "test"
        )
        let (client, _) = makeClient(environment: environment)

        await StubURLProtocol.set { _ in
            let payload = """
            {"token_type":"Bearer","access_token":"new","refresh_token":"r-2","expires_in":3600}
            """.data(using: .utf8)!
            return (payload, 200, [:])
        }

        _ = try await client.requestSiteRoot(AuthEndpoint.exchange(code: "abc", verifier: "verifier"))

        let captured = await StubURLProtocol.recorded()
        let request = try #require(captured.first)
        #expect(request.url?.host == "auth.spark.cronx.co")
        #expect(request.url?.path == "/oauth/token")
    }

    @Test("telemetry captures request and response metadata with redacted credentials")
    func telemetryRedactsCredentials() async throws {
        struct Response: Decodable, Sendable {
            let safe: String
            let accessToken: String

            enum CodingKeys: String, CodingKey {
                case safe
                case accessToken = "access_token"
            }
        }

        let sink = TestTelemetrySink()
        let telemetry = APITelemetry()
        await telemetry.setSink(sink)
        let (client, tokenStore) = makeClient(telemetry: telemetry)
        await tokenStore.store(access: "bearer-secret", refresh: "refresh-secret", expiresIn: 60)

        let requestBody = """
        {"content":"hello","refresh_token":"refresh-secret","nested":{"api_key":"key-secret"}}
        """.data(using: .utf8)!
        let endpoint = Endpoint<Response>(
            method: .post,
            path: "/telemetry",
            body: requestBody,
            contentType: "application/json"
        )

        await StubURLProtocol.set { _ in
            (
                Data(#"{"safe":"ok","access_token":"response-secret"}"#.utf8),
                200,
                ["Content-Type": "application/json", "Set-Cookie": "session=secret"]
            )
        }

        let response = try await client.request(endpoint)
        #expect(response.safe == "ok")

        let event = try await #require(sink.events().first)
        #expect(event.outcome == .success)
        #expect(event.method == "POST")
        #expect(event.statusCode == 200)
        #expect(event.requestHeaders["Authorization"] == "<redacted>")
        #expect(event.responseHeaders["Set-Cookie"] == "<redacted>")

        let capturedRequestBody = String(data: try #require(event.requestBody), encoding: .utf8) ?? ""
        let capturedResponseBody = String(data: try #require(event.responseBody), encoding: .utf8) ?? ""
        #expect(capturedRequestBody.contains(#""content":"hello""#))
        #expect(capturedRequestBody.contains(#""refresh_token":"<redacted>""#))
        #expect(capturedRequestBody.contains(#""api_key":"<redacted>""#))
        #expect(capturedResponseBody.contains(#""access_token":"<redacted>""#))
        #expect(!capturedRequestBody.contains("refresh-secret"))
        #expect(!capturedResponseBody.contains("response-secret"))
    }

    @Test("telemetry captures failed HTTP responses")
    func telemetryCapturesHTTPFailures() async throws {
        let sink = TestTelemetrySink()
        let telemetry = APITelemetry()
        await telemetry.setSink(sink)
        let (client, _) = makeClient(telemetry: telemetry)

        await StubURLProtocol.set { _ in
            (Data(#"{"message":"broken"}"#.utf8), 500, ["Content-Type": "application/json"])
        }

        await #expect(throws: APIError.self) {
            _ = try await client.request(BriefingEndpoint.today())
        }

        let event = try await #require(sink.events().first)
        #expect(event.outcome == .httpError)
        #expect(event.statusCode == 500)
        #expect(event.responseSizeBytes == #"{"message":"broken"}"#.utf8.count)
        #expect(event.durationMillis >= 0)
    }

    @Test("cancelled requests are not captured as telemetry failures")
    func cancellationDoesNotCaptureTelemetryFailure() async throws {
        let sink = TestTelemetrySink()
        let telemetry = APITelemetry()
        await telemetry.setSink(sink)
        let session = makeSession(protocolClasses: [CancelledURLProtocol.self])
        let (client, _) = makeClient(telemetry: telemetry, session: session)

        await #expect(throws: APIError.self) {
            _ = try await client.request(BriefingEndpoint.today())
        }

        #expect(await sink.events().isEmpty)
    }
}

private actor TestTelemetrySink: APITelemetrySink {
    private var captured: [APITelemetryEvent] = []

    func capture(_ event: APITelemetryEvent) {
        captured.append(event)
    }

    func events() -> [APITelemetryEvent] {
        captured
    }
}

private final class CancelledURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }

    override func stopLoading() {}
}
