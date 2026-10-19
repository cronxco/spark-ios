import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("Log draft")
struct LogDraftTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("a beer keeps its serving and quantity")
    func beerDraft() throws {
        let draft = LogDraft(kind: .beer, title: "  Verdant Nebulous Sky ", quantity: 1, serving: .can)

        let request = try draft.request(now: now, idempotencyKey: "k")

        #expect(request.kind == .beer)
        #expect(request.title == "Verdant Nebulous Sky")
        #expect(request.quantity == 1)
        #expect(request.serving == .can)
        #expect(request.idempotencyKey == "k")
        #expect(request.occurredAt == nil)
        #expect(request.episodes == nil)
    }

    @Test("minutes ago becomes an earlier time")
    func minutesAgo() throws {
        let draft = LogDraft(kind: .wine, title: "Cafe François Rouge", quantity: 0.5, unit: "bottle", minutesAgo: 90)

        let request = try draft.request(now: now)

        #expect(request.occurredAt == now.addingTimeInterval(-5_400))
        #expect(request.quantity == 0.5)
        #expect(request.unit == "bottle")
        #expect(request.serving == nil)
    }

    @Test("a serving is only kept for beer")
    func servingOnlyForBeer() throws {
        let request = try LogDraft(kind: .wine, title: "Rioja", serving: .bottle).request(now: now)

        #expect(request.serving == nil)
    }

    @Test("TV episodes are sorted, deduplicated and kept in range")
    func televisionEpisodes() throws {
        let draft = LogDraft(kind: .tv, title: "The Diplomat", season: 3, episodes: [2, 1, 2, 0, 1_000])

        let request = try draft.request(now: now)

        #expect(request.episodes == [1, 2])
        #expect(request.season == 3)
    }

    @Test("a season outside the backend range is dropped")
    func seasonOutOfRange() throws {
        let request = try LogDraft(kind: .tv, title: "The Diplomat", season: 0, episodes: [1]).request(now: now)

        #expect(request.season == nil)
    }

    @Test("TV without episodes asks for them")
    func televisionNeedsEpisodes() {
        #expect(throws: LogDraftIssue.missingEpisodes) {
            try LogDraft(kind: .tv, title: "The Diplomat", episodes: []).request(now: now)
        }
        #expect(throws: LogDraftIssue.missingEpisodes) {
            try LogDraft(kind: .tv, title: "The Diplomat").request(now: now)
        }
    }

    @Test("a blank title is rejected")
    func blankTitle() {
        #expect(throws: LogDraftIssue.missingTitle) {
            try LogDraft(kind: .wine, title: "   ").request(now: now)
        }
    }

    @Test("values the backend would reject are dropped, not sent")
    func outOfRangeValuesDropped() throws {
        let request = try LogDraft(kind: .beer, title: "IPA", quantity: 0, volumeML: 5).request(now: now)

        #expect(request.quantity == nil)
        #expect(request.volumeML == nil)
    }
}

@Suite("Log view model", .serialized)
@MainActor
struct LogViewModelTests {
    private nonisolated static let host = "log.spark.test"

    private nonisolated static func diplomat() -> LogDraft {
        LogDraft(kind: .tv, title: "The Diplomat", episodes: [1, 2])
    }

    @Test("a season question is answered and the request is resent with that season")
    func answersSeasonQuestion() async throws {
        actor Attempts {
            var count = 0
            func next() -> Int { count += 1; return count }
        }
        let attempts = Attempts()
        await AppStubURLProtocol.set(host: Self.host) { _ in
            if await attempts.next() == 1 {
                return (Data(Self.seasonQuestion.utf8), 200, [:])
            }
            return (Data(Self.logged.utf8), 201, [:])
        }
        let model = LogViewModel(extract: { _ in Self.diplomat() })
        let client = try await makeClient()
        model.updateText("Just watched episodes 1 and 2 of The Diplomat")

        await model.submit(using: client)
        guard case .question(let question) = model.phase else {
            Issue.record("Expected a season question, got \(model.phase)")
            return
        }
        #expect(question.field == .season)

        await model.answer(try #require(question.options.first), using: client)

        guard case .logged(let outcome) = model.phase else {
            Issue.record("Expected the entry to be logged, got \(model.phase)")
            return
        }
        #expect(outcome.events.map(\.id) == ["e1", "e2"])

        let requests = await AppStubURLProtocol.recorded(host: Self.host)
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.httpMethod == "POST" && $0.url?.path.hasSuffix("/log") == true })
    }

    @Test("a request the server rejects shows its message")
    func showsServerMessage() async throws {
        await AppStubURLProtocol.set(host: Self.host) { _ in
            (Data(#"{"message":"No TV series found for that title."}"#.utf8), 422, ["Content-Type": "application/json"])
        }
        let model = LogViewModel(extract: { _ in Self.diplomat() })
        model.updateText("Watched episode 1 of Zzzz")

        await model.submit(using: try await makeClient())

        #expect(model.phase == .failed("No TV series found for that title."))
    }

    @Test("an unavailable model says so and sends nothing")
    func modelUnavailable() async throws {
        await AppStubURLProtocol.set(host: Self.host) { _ in (Data(), 500, [:]) }
        let model = LogViewModel(extract: { _ in throw LogExtractionError.unavailable })
        model.updateText("A pint of Guinness")

        await model.submit(using: try await makeClient())

        #expect(model.phase == .failed("Apple Intelligence isn’t available."))
        #expect(await AppStubURLProtocol.recorded(host: Self.host).isEmpty)
    }

    @Test("undo reads each event's version and deletes it")
    func undoDeletesEvents() async throws {
        await AppStubURLProtocol.set(host: Self.host) { request in
            switch request.httpMethod {
            case "POST": return (Data(Self.logged.utf8), 201, [:])
            case "GET": return (Data("{}".utf8), 200, ["ETag": "\"v1\""])
            default: return (Data(#"{"id":"e1","deleted_at":"2026-10-19T20:00:00+00:00"}"#.utf8), 200, [:])
            }
        }
        let model = LogViewModel(extract: { _ in Self.diplomat() })
        let client = try await makeClient()
        model.updateText("Episodes 1 and 2 of The Diplomat")
        await model.submit(using: client)

        await model.undo(using: client)

        #expect(model.phase == .undone)
        let requests = await AppStubURLProtocol.recorded(host: Self.host)
        #expect(requests.map(\.httpMethod) == ["POST", "GET", "DELETE", "GET", "DELETE"])
        #expect(requests.filter { $0.httpMethod == "DELETE" }.allSatisfy { $0.value(forHTTPHeaderField: "If-Match") == "\"v1\"" })
    }

    @Test("a failed undo keeps the entry and its Undo")
    func failedUndoKeepsEntry() async throws {
        await AppStubURLProtocol.set(host: Self.host) { request in
            request.httpMethod == "POST"
                ? (Data(Self.logged.utf8), 201, [:])
                : (Data(#"{"message":"unavailable"}"#.utf8), 500, [:])
        }
        let model = LogViewModel(extract: { _ in Self.diplomat() })
        let client = try await makeClient()
        model.updateText("Episodes 1 and 2 of The Diplomat")
        await model.submit(using: client)

        await model.undo(using: client)

        guard case .logged(let outcome) = model.phase else {
            Issue.record("Expected the entry to stay logged, got \(model.phase)")
            return
        }
        #expect(outcome.events.count == 2)
        #expect(model.undoError != nil)
    }

    private nonisolated static let seasonQuestion = """
    {"status":"needs_clarification","field":"season","question":"Which season?",\
    "options":[{"label":"Season 3","value":3},{"label":"Season 2","value":2}],"suggested":3}
    """

    private nonisolated static let logged = """
    {"status":"logged","events":[\
    {"id":"e1","action":"watched_episode","title":"The Diplomat S03E01","time":"2026-10-19T19:30:00+00:00"},\
    {"id":"e2","action":"watched_episode","title":"The Diplomat S03E02","time":"2026-10-19T19:30:00+00:00"}],\
    "missing_episodes":[]}
    """

    private func makeClient() async throws -> APIClient {
        let tokenStore = KeychainTokenStore(
            service: "co.cronx.sparkapp.tests.log.\(UUID().uuidString)",
            account: "test",
            accessGroup: nil
        )
        try await tokenStore.store(access: "token", refresh: "refresh", expiresIn: 3_600)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStubURLProtocol.self]
        let suite = "spark.etag.log.\(UUID().uuidString)"
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
}
