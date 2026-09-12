import Foundation
import Testing

@testable import Spark
@testable import SparkKit

/// Answering a digest's last question lifts the "still awaiting answers" block,
/// but it is not on its own evidence the digest was read — the reader can jump
/// to the question screen and answer it having met none of the prose.
///
/// These drive the real view model through a stubbed `APIClient`, because the
/// thing under test is which path `onQuestionAnswered` takes, not the read rule
/// itself (that is covered directly in `UpToSpeedReadMarkingTests`).
@Suite("Up to Speed question answering", .serialized)
@MainActor
struct UpToSpeedQuestionReadTests {
    /// Own host: the stub is process-wide and suites run in parallel.
    private static let host = "uptospeed.spark.test"

    private let environment = APIEnvironment(
        baseURL: URL(string: "https://uptospeed.spark.test/api/v1/mobile")!,
        oauthAuthorizeURL: URL(string: "https://uptospeed.spark.test/oauth/authorize")!,
        name: "test"
    )

    @Test("answering the last question does not mark an unread digest caught up")
    func answeringWithoutReadingDoesNotMarkRead() async throws {
        let viewModel = try await loadedViewModel()

        viewModel.onQuestionAnswered(blockID: "block-question", itemID: "digest-a")

        #expect(viewModel.pendingReadRefs.isEmpty)
    }

    @Test("answering the last question marks a digest whose screens were all read")
    func answeringAfterReadingMarksRead() async throws {
        let viewModel = try await loadedViewModel()

        for index in viewModel.screens.indices where viewModel.screens[index].item?.id == "digest-a" {
            viewModel.markScreenConsumed(at: index)
        }
        // Still blocked: the question is outstanding, however much was read.
        #expect(viewModel.pendingReadRefs.isEmpty)

        viewModel.onQuestionAnswered(blockID: "block-question", itemID: "digest-a")

        #expect(viewModel.pendingReadRefs.map(\.id) == ["digest-a"])
    }

    // MARK: - Harness

    private func loadedViewModel() async throws -> UpToSpeedViewModel {
        await AppStubURLProtocol.set(host: Self.host) { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/flint/digests/digest-a") {
                return (Data(Self.digestJSON.utf8), 200, [:])
            }
            if path.hasSuffix("/up-to-speed") {
                return (Data(Self.feedJSON.utf8), 200, [:])
            }
            return (Data("{}".utf8), 200, [:])
        }

        let tokenStore = KeychainTokenStore(
            service: "co.cronx.sparkapp.tests.uptospeed.\(UUID().uuidString)",
            account: "test",
            accessGroup: nil
        )
        try await tokenStore.store(access: "token", refresh: "refresh", expiresIn: 3_600)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStubURLProtocol.self]

        let suite = "spark.etag.uptospeed.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let client = APIClient(
            environment: environment,
            session: URLSession(configuration: configuration),
            tokenStore: tokenStore,
            etagCache: ETagCache(defaults: defaults)
        )

        let viewModel = UpToSpeedViewModel(apiClient: client)
        await viewModel.load()

        // Guard the fixture itself. Both tests turn on the digest's question
        // actually being known, which only happens if the detail fetch decoded
        // — `preloadDigests` swallows failures with `try?`, so a broken fixture
        // would otherwise look like "no questions outstanding" and quietly
        // invert what these tests assert.
        #expect(viewModel.screens.contains { $0.item?.id == "digest-a" })

        // Name the requests the stub actually saw. Runs have failed on this
        // precondition without saying whether the digest detail was even asked
        // for, or under what path. Recorded as an Issue rather than an #expect
        // comment: the CI log prints an issue's own message, but prints only
        // the expression of a failed expectation, so a comment never surfaces.
        if !viewModel.openQuestions.contains(where: { $0.block.id == "block-question" }) {
            let requested = await AppStubURLProtocol.recorded(host: Self.host)
                .map { $0.url?.path ?? "<no path>" }
            Issue.record("digest detail did not load. Paths requested: \(requested)")
        }

        return viewModel
    }

    // nonisolated: the suite is @MainActor, but the stub handler is @Sendable
    // and runs off the main actor. Immutable and Sendable, so this is safe.
    private nonisolated static let feedJSON = """
    {"items":[{
      "id":"digest-a",
      "type":"flint_digest",
      "caught_up_at":null,
      "payload":{
        "date":"2026-09-11",
        "period":"morning",
        "title":"Morning briefing",
        "summary":"First paragraph of the briefing.\\n\\nSecond paragraph of the briefing.",
        "block_count":1,
        "unanswered_question_count":1
      }
    }]}
    """

    private nonisolated static let digestJSON = """
    {
      "event_id":"digest-a",
      "date":"2026-09-11",
      "period":"morning",
      "title":"Morning briefing",
      "summary":"First paragraph of the briefing.\\n\\nSecond paragraph of the briefing.",
      "block_count":1,
      "unanswered_question_count":1,
      "blocks":[{
        "id":"block-question",
        "block_type":"flint_user_question",
        "title":"A question",
        "question":"How did that land?",
        "answered":false
      }]
    }
    """
}
