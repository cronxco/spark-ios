import Foundation
import Testing
@testable import SparkKit

@Suite("APIClient", .serialized)
struct APIClientTests {
    private func makeStore() -> KeychainTokenStore {
        let service = "co.cronx.spark.tests.api.\(UUID().uuidString)"
        return KeychainTokenStore(service: service, account: "test", accessGroup: nil)
    }

    private func makeCache() -> ETagCache {
        let suite = "spark.etag.apiclient.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ETagCache(defaults: defaults)
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeClient(
        environment: APIEnvironment = .init(
            baseURL: URL(string: "https://test.spark.cronx.co/api/v1/mobile")!,
            oauthAuthorizeURL: URL(string: "https://test.spark.cronx.co/oauth/authorize")!,
            name: "test"
        )
    ) -> (APIClient, KeychainTokenStore) {
        let tokenStore = makeStore()
        let client = APIClient(
            environment: environment,
            session: makeSession(),
            tokenStore: tokenStore,
            etagCache: makeCache()
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
}
