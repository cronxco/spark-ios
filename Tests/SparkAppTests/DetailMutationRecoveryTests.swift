import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("Completed detail mutations", .serialized)
@MainActor
struct DetailMutationRecoveryTests {
    private nonisolated static let host = "detail-mutation.spark.test"
    private nonisolated static let objectJSON = #"{"id":"obj_1","concept":"place","type":"cafe","title":"Corner Cafe","tags":[]}"#

    @Test("a successful relationship delete survives a failed detail refresh")
    func deletedRelationshipIsNotReportedAsFailed() async throws {
        await AppStubURLProtocol.set(host: Self.host) { request in
            if request.httpMethod == "DELETE" { return (Data(), 204, [:]) }
            return (Data(#"{"message":"temporarily unavailable"}"#.utf8), 500, [:])
        }
        let model = try await makeModel()
        try await model.deleteRelationship(relationship())

        #expect(model.etag == nil)
        guard case .error = model.state else {
            Issue.record("Stale detail must be replaced by a retryable error")
            return
        }
        let requests = await AppStubURLProtocol.recorded(host: Self.host)
        #expect(requests.map(\.httpMethod) == ["DELETE", "GET"])
        #expect(requests.first?.value(forHTTPHeaderField: "If-Match") == "\"edge\"")
    }

    @Test("a failed relationship delete still propagates and does not refresh")
    func rejectedRelationshipDeleteStillFails() async throws {
        await AppStubURLProtocol.set(host: Self.host) { _ in
            (Data(#"{"message":"changed elsewhere"}"#.utf8), 412, [:])
        }
        let model = try await makeModel()
        await #expect(throws: APIError.self) {
            try await model.deleteRelationship(relationship())
        }
        #expect(model.etag == "\"old\"")
        #expect(await AppStubURLProtocol.recorded(host: Self.host).count == 1)
    }

    @Test("restoration completes even when refresh fails, and Retry reloads its version")
    func restoredObjectWaitsForFreshDetail() async throws {
        await AppStubURLProtocol.set(host: Self.host) { request in
            switch request.httpMethod {
            case "DELETE":
                return (Data(#"{"id":"obj_1","deleted_at":"2026-10-04T09:30:00+01:00"}"#.utf8), 200, [:])
            case "POST":
                return (Data(Self.objectJSON.utf8), 200, [:])
            default:
                return (Data(#"{"message":"temporarily unavailable"}"#.utf8), 500, [:])
            }
        }
        let model = try await makeModel()
        try await model.delete()
        #expect(model.isDeleted)
        try await model.restore()
        #expect(!model.isDeleted)
        #expect(model.etag == nil)
        guard case .error = model.state else {
            Issue.record("Mutations must remain unavailable until Retry reloads detail")
            return
        }
        let requests = await AppStubURLProtocol.recorded(host: Self.host)
        #expect(requests.map(\.httpMethod) == ["DELETE", "POST", "GET"])

        await AppStubURLProtocol.set(host: Self.host) { _ in
            (Data(Self.objectJSON.utf8), 200, ["ETag": "\"fresh\""])
        }
        await model.load()
        #expect(model.etag == "\"fresh\"")
        guard case .loaded = model.state else {
            Issue.record("Retry must restore usable detail")
            return
        }
    }

    private func relationship() throws -> EntityRelationship {
        try JSONDecoder().decode(EntityRelationship.self, from: Data(#"{"id":"edge_1","from_type":"object","from_id":"obj_1","to_type":"event","to_id":"evt_1","type":"related_to","etag":"\"edge\""}"#.utf8))
    }

    private func makeModel() async throws -> ObjectDetailViewModel {
        let store = KeychainTokenStore(service: "spark.tests.detail-mutation.\(UUID().uuidString)", account: "test", accessGroup: nil)
        try await store.store(access: "token", refresh: "refresh", expiresIn: 3_600)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStubURLProtocol.self]
        let defaults = UserDefaults(suiteName: "spark.tests.detail-etag.\(UUID().uuidString)")!
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
        let model = ObjectDetailViewModel(objectId: "obj_1", apiClient: client)
        model.etag = "\"old\""
        model.state = .loaded(try JSONDecoder().decode(ObjectDetail.self, from: Data(Self.objectJSON.utf8)))
        return model
    }
}
