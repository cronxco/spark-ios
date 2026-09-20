import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("Flint notes", .serialized)
@MainActor
struct FlintNotesTests {
    private static let host = "flint-notes.spark.test"

    @Test("composer retries an unchanged note with the same mutation identity")
    func composerRetryIsIdempotent() async throws {
        actor Attempts {
            var count = 0
            func next() -> Int { count += 1; return count }
        }
        let attempts = Attempts()
        await AppStubURLProtocol.set(host: Self.host) { _ in
            if await attempts.next() == 1 {
                return (Data(#"{"message":"temporary"}"#.utf8), 500, ["Content-Type": "application/json"])
            }
            return (Data(Self.noteResponse.utf8), 201, ["Content-Type": "application/json"])
        }
        let client = try await makeClient()
        let model = FlintNoteComposerModel(context: .digest(id: "digest-1", label: "Morning Digest"))
        model.updateBody("Keep Friday evening free.")

        #expect(await model.submit(using: client, now: Date(timeIntervalSince1970: 1_000)) == nil)
        #expect(await model.submit(using: client, now: Date(timeIntervalSince1970: 2_000))?.id == "note-1")

        let requests = await AppStubURLProtocol.recorded(host: Self.host)
        let bodies = try requests.map { request -> [String: Any] in
            let body = try #require(request.httpBody)
            return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        }
        #expect(bodies.count == 2)
        #expect(bodies[0]["client_mutation_id"] as? String == bodies[1]["client_mutation_id"] as? String)
        #expect(bodies[0]["authored_at"] as? String == bodies[1]["authored_at"] as? String)
        #expect((bodies[0]["context_links"] as? [[String: String]])?.first?["id"] == "digest-1")
    }

    @Test("editing after failure creates a new mutation identity")
    func editedRetryGetsNewIdentity() async throws {
        actor Attempts {
            var count = 0
            func next() -> Int { count += 1; return count }
        }
        let attempts = Attempts()
        await AppStubURLProtocol.set(host: Self.host) { _ in
            if await attempts.next() == 1 {
                return (Data(#"{"message":"temporary"}"#.utf8), 500, ["Content-Type": "application/json"])
            }
            return (Data(Self.noteResponse.utf8), 201, ["Content-Type": "application/json"])
        }
        let client = try await makeClient()
        let model = FlintNoteComposerModel(context: .generic)
        model.updateBody("First version")
        _ = await model.submit(using: client, now: Date(timeIntervalSince1970: 1_000))
        model.updateBody("Second version")
        _ = await model.submit(using: client, now: Date(timeIntervalSince1970: 2_000))

        let requests = await AppStubURLProtocol.recorded(host: Self.host)
        let bodies = try requests.map { request -> [String: Any] in
            let body = try #require(request.httpBody)
            return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        }
        #expect(bodies[0]["client_mutation_id"] as? String != bodies[1]["client_mutation_id"] as? String)
        #expect(bodies[0]["authored_at"] as? String != bodies[1]["authored_at"] as? String)
    }

    @Test("Up to Speed maps cards to the strongest supported context")
    func upToSpeedContextMapping() {
        let digestItem = UpToSpeedItem(
            id: "digest-1",
            type: .flintDigest,
            caughtUpAt: nil,
            payload: .flintDigest(.init(
                date: "2026-09-16",
                period: .morning,
                title: "Morning Digest",
                blockCount: 1,
                unansweredQuestionCount: 0
            ))
        )
        let block = FlintDigestBlock(id: "block-1", blockType: "flint_insight", title: "Recovery")
        let checkInItem = UpToSpeedItem(
            id: "check-in-1",
            type: .checkIn,
            caughtUpAt: nil,
            payload: .checkIn(.init(period: .morning, date: "2026-09-16", completed: true, eventId: "event-1"))
        )

        let newsItem = UpToSpeedItem(
            id: "event-news-1",
            type: .newsSummary,
            caughtUpAt: nil,
            payload: .newsSummary(.init(title: "Rates hold steady", source: "example.com"))
        )

        #expect(UpToSpeedScreen.flintHeader(digestItem, firstSection: nil).flintNoteContext.link == .init(type: .digest, id: "digest-1"))
        // A news summary links to its event, not to a digest it is not part of.
        #expect(UpToSpeedScreen.newsSummary(newsItem).flintNoteContext.link == .init(type: .event, id: "event-news-1"))
        #expect(UpToSpeedScreen.newsSummary(newsItem).flintNoteContext.label == "Rates hold steady")
        #expect(UpToSpeedScreen.flintInsight(digestItem, block).flintNoteContext.link == .init(type: .block, id: "block-1"))
        #expect(UpToSpeedScreen.checkIn(checkInItem).flintNoteContext.link == .init(type: .event, id: "event-1"))
        #expect(UpToSpeedScreen.opener.flintNoteContext.link == nil)
        #expect(UpToSpeedScreen.wrap.flintNoteContext.link == nil)
    }

    private func makeClient() async throws -> APIClient {
        let tokenStore = KeychainTokenStore(
            service: "co.cronx.sparkapp.tests.flint-notes.\(UUID().uuidString)",
            account: "test",
            accessGroup: nil
        )
        try await tokenStore.store(access: "token", refresh: "refresh", expiresIn: 3_600)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStubURLProtocol.self]
        let suite = "spark.etag.flint-notes.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        return APIClient(
            environment: APIEnvironment(
                baseURL: URL(string: "https://\(Self.host)/api/v1/mobile")!,
                oauthAuthorizeURL: URL(string: "https://\(Self.host)/oauth/authorize")!,
                name: "test"
            ),
            session: URLSession(configuration: configuration),
            tokenStore: tokenStore,
            etagCache: ETagCache(defaults: defaults)
        )
    }

    private nonisolated static let noteResponse = """
    {"data":{"id":"note-1","title":"Note to Flint","body":"Saved","authored_at":null,"created_at":null,"deleted_at":null,"context_links":[],"consent_version":"flint-note-v1","consented_at":null,"version":"\\\"v1\\\""}}
    """
}
