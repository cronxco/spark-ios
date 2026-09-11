import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("Up to Speed read marking")
struct UpToSpeedReadMarkingTests {
    // A day-context screen is appended once, after every digest chapter has
    // built its screens — so it isn't necessarily adjacent to the rest of
    // its own item's screens when another digest's screens land in between.
    // `isLastScreen` has to scan forward rather than compare only against
    // index + 1, or a digest whose day-context screen trails behind another
    // digest's content would either get marked read too early (before its
    // day-context screen is shown) or never get marked read at all.
    @Test func lastScreenScansForwardPastInterveningScreens() {
        let itemA = digest(id: "digest-a")
        let itemB = digest(id: "digest-b")

        let screens: [UpToSpeedScreen] = [
            .flintHeader(itemA, firstSection: "A's opening"),
            .flintParagraph(itemA, text: "A's body", index: 0),
            .flintHeader(itemB, firstSection: "B's opening"),
            .dayContext(itemA, FlintDayContext(), yesterday: nil),
        ]

        // Index 1 (A's last *contiguous* screen) is not actually the last
        // A-tagged screen — its day-context screen is still ahead, past B.
        #expect(UpToSpeedViewModel.isLastScreen(forItemID: "digest-a", at: 1, in: screens) == false)
        // Index 3 (the day-context screen itself) is genuinely the last.
        #expect(UpToSpeedViewModel.isLastScreen(forItemID: "digest-a", at: 3, in: screens) == true)
        // B has only one screen, so it's last right away.
        #expect(UpToSpeedViewModel.isLastScreen(forItemID: "digest-b", at: 2, in: screens) == true)
    }

    @Test func lastScreenIsTrueAtTheFinalIndex() {
        let item = digest(id: "digest-solo")
        let screens: [UpToSpeedScreen] = [.flintHeader(item, firstSection: nil)]
        #expect(UpToSpeedViewModel.isLastScreen(forItemID: "digest-solo", at: 0, in: screens) == true)
    }

    private func digest(id: String) -> UpToSpeedItem {
        UpToSpeedItem(
            id: id,
            type: .flintDigest,
            caughtUpAt: nil,
            payload: .flintDigest(UpToSpeedFlintDigestSummary(
                date: "2026-09-11",
                period: .morning,
                title: nil,
                summary: nil,
                blockCount: 0,
                unansweredQuestionCount: 0
            ))
        )
    }
}
