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


    @Test func readBriefingStillSuppliesDayContext() async throws {
        let date = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let feed = Self.feedJSON
            .replacingOccurrences(of: "2026-09-11", with: date)
            .replacingOccurrences(of: "\"caught_up_at\":null", with: "\"caught_up_at\":\"2026-09-13T10:00:00Z\"")
        let detail = """
        {"event_id":"digest-a","date":"\(date)","title":"Your day","blocks":[
          {"id":"day","block_type":"flint_day_context","title":"Today",
           "day_context":{"date":"\(date)","calendar":[{"title":"Lunch","all_day":true}],"weather":{"location":"London","temp_high_c":21}}}
        ]}
        """
        let vm = try await loadedViewModel(feed: feed, detail: detail, expectsQuestion: false)
        #expect(vm.openerDayContext?.calendar.first?.title == "Lunch")
        #expect(!vm.screens.contains { $0.item?.id == "digest-a" })
        #expect(vm.screens.last?.id == "wrap")
        #expect(!vm.screens.contains { $0.id == "recap" })
        #expect(vm.recapItems.map(\.id) == ["digest-a"])
        #expect(vm.pendingReadRefs.isEmpty)
    }

    @Test func sessionReadAppearsInRecapWithoutDuplicateEntries() async throws {
        let vm = try await loadedViewModel()
        for index in vm.screens.indices where vm.screens[index].item?.id == "digest-a" {
            vm.markScreenConsumed(at: index)
        }
        vm.onQuestionAnswered(blockID: "block-question", itemID: "digest-a")
        vm.onQuestionAnswered(blockID: "block-question", itemID: "digest-a")
        #expect(vm.recapItems.map(\.id) == ["digest-a"])
    }

    @Test func readingRecapDetailDoesNotEmitReadRequests() async throws {
        let vm = try await loadedViewModel()
        let item = try #require(vm.screens.first(where: { $0.item != nil })?.item)
        let detail = try await vm.recapDigest(for: item)
        #expect(detail.id == item.id)
        #expect(vm.pendingReadRefs.isEmpty)
        let requests = await AppStubURLProtocol.recorded(host: Self.host)
        #expect(!requests.contains { $0.httpMethod == "POST" })
    }

    @Test func staleDayContextIsNotPresentedAsToday() {
        let context = FlintDayContext(calendar: [.init(title: "Old appointment")])
        let digest = FlintDigest(eventID: "old", date: "2020-01-01", title: "Old brief", blockCount: 1,
            blocks: [.init(id: "day", blockType: "flint_day_context", title: "Day", dayContext: context)])
        #expect(UpToSpeedViewModel.dayContext(from: [digest], now: .now, calendar: .current) == nil)
    }

    @Test func publicationUsesSourceHostInsteadOfIngestionMethod() {
        #expect(NewsSummaryScreen.publication(for: NewsSummary(title: "News", source: "fetch", url: "https://www.economist.com/the-world-in-brief")) == "The Economist")
        #expect(NewsSummaryScreen.publication(for: NewsSummary(title: "News", source: "fetch", url: "https://ft.com/content/story")) == "Financial Times")
        #expect(NewsSummaryScreen.publication(for: NewsSummary(title: "News", source: "newsletter")) == "Newsletter")
    }

    @Test func restoreStaysOnCurrentPageUntilRecapCloses() async throws {
        let vm = try await loadedViewModel()
        vm.jump(to: 1)
        let item = try #require(vm.screens[1].item)
        let page = vm.screens[vm.currentIndex].id
        #expect(await vm.unmark(item))
        #expect(vm.restoredIDs.contains(item.id))
        #expect(vm.screens[vm.currentIndex].id == page)
        #expect(!(await vm.unmark(item)))
    }

    @Test func failedRestoreDoesNotChangeJourney() async throws {
        let vm = try await loadedViewModel(restoreStatus: 500)
        let item = try #require(vm.screens.first(where: { $0.item != nil })?.item)
        let pages = vm.screens.map(\.id)
        #expect(!(await vm.unmark(item)))
        #expect(vm.restoredIDs.isEmpty)
        #expect(vm.screens.map(\.id) == pages)
    }

    // MARK: - Headlines tier

    @Test("articles form their own Headlines chapter behind a contents page")
    func articlesFormAHeadlinesChapter() async throws {
        let viewModel = try await loadedViewModel(feed: Self.newsFeedJSON, expectsQuestion: false)

        let kinds = viewModel.chapters.map(\.kind)
        #expect(kinds.contains(.headlines))
        #expect(!kinds.contains(.news))
        let headlines = try #require(viewModel.chapters.first { $0.kind == .headlines })
        #expect(headlines.cardCount == 2)
        guard case .headlinesIndex(let listed, _) = viewModel.screens[headlines.range.lowerBound] else {
            Issue.record("Headlines should open on its contents page")
            return
        }
        #expect(listed.map(\.id) == ["news-a"])
    }

    @Test("the toolbar can mark an article read without the dwell")
    func manualMarkRead() async throws {
        let viewModel = try await loadedViewModel(feed: Self.newsFeedJSON, expectsQuestion: false)
        let item = try #require(newsItem(in: viewModel))

        #expect(!viewModel.isMarkedRead("news-a"))
        await viewModel.toggleRead(item)

        #expect(viewModel.isMarkedRead("news-a"))
        #expect(viewModel.pendingReadRefs.contains { $0.id == "news-a" })
    }

    @Test("a manually unmarked article is not re-marked by the dwell")
    func manualUnmarkSticks() async throws {
        let viewModel = try await loadedViewModel(feed: Self.newsFeedJSON, expectsQuestion: false)
        let item = try #require(newsItem(in: viewModel))
        let index = try #require(viewModel.articleScreenIndex(itemID: "news-a"))

        viewModel.markScreenConsumed(at: index)
        #expect(viewModel.isMarkedRead("news-a"))

        await viewModel.toggleRead(item)
        #expect(!viewModel.isMarkedRead("news-a"))
        #expect(!viewModel.pendingReadRefs.contains { $0.id == "news-a" })

        // Swiping on re-runs the read test; it must respect the reader.
        viewModel.markRead(at: index)
        #expect(!viewModel.isMarkedRead("news-a"))
        #expect(!viewModel.pendingReadRefs.contains { $0.id == "news-a" })

        // And the button still works the other way.
        await viewModel.toggleRead(item)
        #expect(viewModel.isMarkedRead("news-a"))
    }

    private func newsItem(in viewModel: UpToSpeedViewModel) -> UpToSpeedItem? {
        viewModel.screens.lazy.compactMap { screen -> UpToSpeedItem? in
            if case .newsSummary(let item) = screen { return item }
            return nil
        }.first
    }

    private nonisolated static let newsFeedJSON = """
    {"items":[{
      "id":"news-a",
      "type":"news_summary",
      "caught_up_at":null,
      "payload":{
        "title":"City verdict lands",
        "publication":"POLITICO London Playbook",
        "source":"newsletter",
        "tldr":"The commission found against City."
      }
    }]}
    """

    private func loadedViewModel(feed: String = Self.feedJSON, detail: String = Self.digestJSON, expectsQuestion: Bool = true, restoreStatus: Int = 200) async throws -> UpToSpeedViewModel {
        await AppStubURLProtocol.set(host: Self.host) { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/flint/digests/digest-a") {
                return (Data(detail.utf8), 200, [:])
            }
            if path.hasSuffix("/up-to-speed") {
                return (Data(feed.utf8), 200, [:])
            }
            if path.hasSuffix("/unmark") { return (Data("{\"unmarked\":1}".utf8), restoreStatus, [:]) }
            if path.hasSuffix("/read") { return (Data("{\"marked\":1}".utf8), 200, [:]) }
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
        // invert what these tests assert. That is exactly what happened: the
        // digest JSON below omits `digest_object_id`, which the decoder used to
        // reject outright. Kept omitted on purpose — the shape is legitimate,
        // and SparkKit now has its own regression test for it.
        if expectsQuestion {
            #expect(viewModel.screens.contains { $0.item?.id == "digest-a" })
            #expect(viewModel.openQuestions.contains { $0.block.id == "block-question" })
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
