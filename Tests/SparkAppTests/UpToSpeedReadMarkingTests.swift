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

    // The shipped bug: the scaffold's bottom sentinel fired on first render,
    // so every card reported "scrolled to the bottom" and one forward swipe
    // marked it caught up. Nothing may be marked read unless the reader has
    // actually finished the card.
    @Test func unconsumedScreensAreNeverMarkedRead() {
        let item = newsSummary(id: "news-a")
        let screens: [UpToSpeedScreen] = [.newsSummary(item)]

        #expect(target(at: 0, in: screens, consumed: []) == nil)
    }

    @Test func consumedNewsSummaryIsMarkedRead() {
        let item = newsSummary(id: "news-a")
        let screens: [UpToSpeedScreen] = [.newsSummary(item)]

        let ref = target(at: 0, in: screens, consumed: [0])
        #expect(ref?.id == "news-a")
        #expect(ref?.type == UpToSpeedItemType.newsSummary.rawValue)
    }

    // Consuming one page of a multi-page digest isn't finishing the digest.
    @Test func consumingAnEarlyDigestPageDoesNotMarkTheDigestRead() {
        let item = digest(id: "digest-a")
        let screens: [UpToSpeedScreen] = [
            .flintHeader(item, firstSection: "opening"),
            .flintParagraph(item, text: "body", index: 0),
        ]

        #expect(target(at: 0, in: screens, consumed: [0]) == nil)
    }

    @Test func consumingTheLastDigestPageMarksTheDigestRead() {
        let item = digest(id: "digest-a")
        let screens: [UpToSpeedScreen] = [
            .flintHeader(item, firstSection: "opening"),
            .flintParagraph(item, text: "body", index: 0),
        ]

        let ref = target(at: 1, in: screens, consumed: [0, 1])
        #expect(ref?.id == "digest-a")
        #expect(ref?.type == UpToSpeedItemType.flintDigest.rawValue)
    }

    @Test func consumingOnlyTheLastDigestPageDoesNotMarkTheDigestRead() {
        let item = digest(id: "digest-a")
        let screens: [UpToSpeedScreen] = [
            .flintHeader(item, firstSection: "opening"),
            .flintParagraph(item, text: "body", index: 0),
        ]

        #expect(target(at: 1, in: screens, consumed: [1]) == nil)
    }

    // A digest with a question Flint is still waiting on isn't finished, even
    // if every page of its prose has been read.
    @Test func digestWithUnansweredQuestionsIsNotMarkedRead() {
        let item = digest(id: "digest-a")
        let screens: [UpToSpeedScreen] = [.flintParagraph(item, text: "body", index: 0)]

        #expect(target(at: 0, in: screens, consumed: [0], awaiting: ["digest-a"]) == nil)
        #expect(target(at: 0, in: screens, consumed: [0], awaiting: ["digest-b"])?.id == "digest-a")
    }

    // Check-ins and anomalies have their own completion signals — submitting
    // the check-in, acknowledging the anomaly — so reading the card is not it.
    @Test func checkInAndAnomalyScreensAreNeverMarkedReadByReading() {
        let checkInItem = newsSummary(id: "check-in")
        let anomalyItem = newsSummary(id: "anomaly")
        let screens: [UpToSpeedScreen] = [.checkIn(checkInItem), .anomaly(anomalyItem)]

        #expect(target(at: 0, in: screens, consumed: [0, 1]) == nil)
        #expect(target(at: 1, in: screens, consumed: [0, 1]) == nil)
    }

    private func target(
        at index: Int,
        in screens: [UpToSpeedScreen],
        consumed: Set<Int>,
        awaiting: Set<String> = []
    ) -> UpToSpeedReadRef? {
        UpToSpeedViewModel.readTarget(
            at: index,
            in: screens,
            consumed: consumed,
            digestsAwaitingAnswers: awaiting
        )
    }

    private func newsSummary(id: String) -> UpToSpeedItem {
        UpToSpeedItem(
            id: id,
            type: .newsSummary,
            caughtUpAt: nil,
            payload: .newsSummary(NewsSummary(
                title: "A story",
                source: "newsletter",
                url: nil,
                time: nil,
                tldr: nil,
                summary: nil,
                keyTakeaways: nil
            ))
        )
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
