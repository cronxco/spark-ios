import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@MainActor
@Suite("Up to Speed digest screens")
struct UpToSpeedDigestScreenTests {
    @Test func contentlessDigestCreatesNoScreens() {
        let screens = makeViewModel().expandFlintItem(
            item: digestItem(title: nil, summary: nil),
            summary: digestSummary(title: nil, summary: nil),
            digest: nil
        )

        #expect(screens.isEmpty)
    }

    @Test func punctuationOnlyDigestCreatesNoScreens() {
        let screens = makeViewModel().expandFlintItem(
            item: digestItem(title: " ", summary: "---"),
            summary: digestSummary(title: " ", summary: "---"),
            digest: nil
        )

        #expect(screens.isEmpty)
    }

    @Test func countOnlyDigestStillCreatesUsefulHeader() {
        let summary = digestSummary(title: nil, summary: nil, blockCount: 3)
        let screens = makeViewModel().expandFlintItem(
            item: digestItem(summary: summary),
            summary: summary,
            digest: nil
        )

        #expect(screens.count == 1)
        guard let first = screens.first, case .flintHeader = first else {
            Issue.record("Expected a digest header")
            return
        }
    }

    @Test func emptyBlocksAreExcludedFromDigestScreens() {
        let summary = digestSummary(title: nil, summary: nil)
        let item = digestItem(summary: summary)
        let digest = FlintDigest(
            eventID: item.id,
            date: "2026-06-14",
            period: .morning,
            title: "Morning Digest",
            blockCount: 3,
            blocks: [
                FlintDigestBlock(id: "empty", blockType: "flint_insight", title: " "),
                FlintDigestBlock(
                    id: "insight",
                    blockType: "flint_insight",
                    title: "Useful insight"
                ),
                FlintDigestBlock(
                    id: "question",
                    blockType: "flint_user_question",
                    title: "",
                    question: "How are you feeling?"
                ),
            ]
        )

        let screens = makeViewModel().expandFlintItem(
            item: item,
            summary: summary,
            digest: digest
        )

        #expect(screens.count == 2)
        guard case .flintInsight = screens[0] else {
            Issue.record("Expected the renderable insight")
            return
        }
        guard case .flintQuestion = screens[1] else {
            Issue.record("Expected the renderable question")
            return
        }
    }

    private func makeViewModel() -> UpToSpeedViewModel {
        UpToSpeedViewModel(apiClient: APIClient(tokenStore: KeychainTokenStore()))
    }

    private func digestSummary(
        title: String?,
        summary: String?,
        blockCount: Int = 0
    ) -> UpToSpeedFlintDigestSummary {
        UpToSpeedFlintDigestSummary(
            date: "2026-06-14",
            period: .morning,
            title: title,
            summary: summary,
            blockCount: blockCount,
            unansweredQuestionCount: 0
        )
    }

    private func digestItem(
        title: String? = nil,
        summary: String? = nil
    ) -> UpToSpeedItem {
        digestItem(summary: digestSummary(title: title, summary: summary))
    }

    private func digestItem(summary: UpToSpeedFlintDigestSummary) -> UpToSpeedItem {
        UpToSpeedItem(
            id: "digest-1",
            type: .flintDigest,
            caughtUpAt: nil,
            payload: .flintDigest(summary)
        )
    }
}
