import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("Live Activity manager identifiers")
@MainActor
struct LiveActivityManagerTests {
    private nonisolated static let host = "live-activity-manager.spark.test"

    @Test("token rotation, updates and end use ActivityKit's ID, not the returned row ID")
    func followUpRequestsKeepActivityKitIdentifier() async throws {
        await AppStubURLProtocol.set(host: Self.host) { request in
            if request.httpMethod == "DELETE" { return (Data(), 204, [:]) }
            // Deliberately distinct from the ActivityKit ID supplied below.
            return (Data(#"{"id":"server-row-987","activity_id":"activitykit-123","activity_type":"daily"}"#.utf8), 200, [:])
        }
        let store = KeychainTokenStore(service: "spark.tests.live-activity.\(UUID().uuidString)", account: "test", accessGroup: nil)
        try await store.store(access: "token", refresh: "refresh", expiresIn: 3_600)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStubURLProtocol.self]
        let defaults = UserDefaults(suiteName: "spark.tests.live-activity-etag.\(UUID().uuidString)")!
        let client = APIClient(
            environment: APIEnvironment(
                baseURL: URL(string: "https://\(Self.host)/api/v1/mobile")!,
                oauthAuthorizeURL: URL(string: "https://\(Self.host)/oauth/authorize")!,
                name: "test"
            ),
            session: URLSession(configuration: configuration),
            tokenStore: store,
            etagCache: ETagCache(defaults: defaults)
        )
        let manager = LiveActivityManager()
        let state = DailyActivityAttributes.DailyContentState()
        try await manager.registerPushToken(activityID: "activitykit-123", token: "first", type: "daily", contentState: state, using: client)
        try await manager.registerPushToken(activityID: "activitykit-123", token: "rotated", type: "daily", contentState: state, using: client)
        await manager.mirrorUpdate(state, activityID: "activitykit-123", using: client)
        await manager.endServerActivity(id: "activitykit-123", using: client)

        let requests = await AppStubURLProtocol.recorded(host: Self.host)
        #expect(requests.map(\.httpMethod) == ["POST", "POST", "PATCH", "DELETE"])
        #expect(requests.map { $0.url?.path } == [
            "/api/v1/mobile/live-activities",
            "/api/v1/mobile/live-activities/activitykit-123/tokens",
            "/api/v1/mobile/live-activities/activitykit-123",
            "/api/v1/mobile/live-activities/activitykit-123",
        ])
        #expect(requests.allSatisfy { $0.url?.path.contains("server-row-987") == false })
        await store.clear()
    }
}
