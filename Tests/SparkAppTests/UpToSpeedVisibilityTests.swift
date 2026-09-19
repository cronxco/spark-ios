import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("Up to Speed visibility")
struct UpToSpeedVisibilityTests {
    @Test func morningShowsOnlyIncompleteMorningCheckIn() throws {
        let visible = visibility(hour: 9).visibleUnreadItems(from: [
            checkIn(.morning, completed: false),
            checkIn(.afternoon, completed: false),
        ])

        #expect(visible.map(\.id) == ["morning:2026-05-24"])
    }

    @Test func morningHidesCompletedMorningAndFutureAfternoonCheckIns() throws {
        let visible = visibility(hour: 9).visibleUnreadItems(from: [
            checkIn(.morning, completed: true),
            checkIn(.afternoon, completed: false),
        ])

        #expect(visible.isEmpty)
    }

    @Test func afternoonShowsAnyIncompleteCheckIns() throws {
        let visible = visibility(hour: 13).visibleUnreadItems(from: [
            checkIn(.morning, completed: false),
            checkIn(.afternoon, completed: false),
        ])

        #expect(visible.map(\.id) == ["morning:2026-05-24", "afternoon:2026-05-24"])
    }

    @Test func afternoonShowsOnlyAfternoonWhenMorningIsComplete() throws {
        let visible = visibility(hour: 13).visibleUnreadItems(from: [
            checkIn(.morning, completed: true),
            checkIn(.afternoon, completed: false),
        ])

        #expect(visible.map(\.id) == ["afternoon:2026-05-24"])
    }

    @Test func completedCheckInsAreHiddenEvenWithoutCaughtUpAt() throws {
        let visible = visibility(hour: 13).visibleUnreadItems(from: [
            checkIn(.morning, completed: true),
            checkIn(.afternoon, completed: true),
        ])

        #expect(visible.isEmpty)
    }

    @Test func keepsEveryUnreadDigest() throws {
        // The chaptered flow shows the morning brief, the news roundup and the
        // reading list together — nothing is collapsed to "most recent".
        let visible = visibility(hour: 9).visibleUnreadItems(from: [
            digest(id: "digest-news", date: "2026-05-24", period: .morning),
            digest(id: "digest-morning", date: "2026-05-24", period: .morning),
            digest(id: "digest-evening", date: "2026-05-24", period: .evening),
            news(),
        ])

        #expect(visible.map(\.id) == ["digest-news", "digest-morning", "digest-evening", "news-1"])
    }

    @Test func dropsDigestsAlreadyCaughtUp() throws {
        let visible = visibility(hour: 9).visibleUnreadItems(from: [
            digest(id: "digest-read", date: "2026-05-24", period: .morning, caughtUpAt: .now),
            digest(id: "digest-unread", date: "2026-05-24", period: .evening),
        ])

        #expect(visible.map(\.id) == ["digest-unread"])
    }

    // -------------------------------------------------------------------------
    // Dismissed anomalies
    // -------------------------------------------------------------------------

    /// The feed is asked for dismissed anomalies so the recap can offer them
    /// back. They arrive with caughtUpAt null — acknowledgement is tracked
    /// separately — so without an explicit check they would reappear in the
    /// flow the instant they were dismissed.
    @Test func dismissedAnomaliesDoNotReturnToTheFlow() throws {
        let visible = visibility(hour: 9).visibleUnreadItems(from: [
            anomaly(id: "anomaly-live"),
            anomaly(id: "anomaly-dismissed", acknowledgedAt: .now),
        ])

        #expect(visible.map(\.id) == ["anomaly-live"])
    }

    // -------------------------------------------------------------------------
    // Recap
    // -------------------------------------------------------------------------

    @Test func recapCollectsEverythingAlreadyDealtWith() throws {
        let earlier = timestamp(hour: 7)
        let later = timestamp(hour: 8)

        let recap = visibility(hour: 9).caughtUpItems(from: [
            digest(id: "digest-read", date: "2026-05-24", period: .morning, caughtUpAt: earlier),
            digest(id: "digest-unread", date: "2026-05-24", period: .evening),
            anomaly(id: "anomaly-dismissed", acknowledgedAt: later),
            anomaly(id: "anomaly-live"),
        ])

        // Newest first, so the most recent mistake is easiest to undo.
        #expect(recap.map(\.id) == ["anomaly-dismissed", "digest-read"])
    }

    @Test func recapIncludesAllReturnedHistory() throws {
        let recap = visibility(hour: 9).caughtUpItems(from: [
            digest(
                id: "digest-old",
                date: "1970-01-01",
                period: .morning,
                caughtUpAt: Date(timeIntervalSince1970: 2_000)
            ),
            anomaly(id: "anomaly-today", acknowledgedAt: timestamp(hour: 8)),
        ])

        #expect(recap.map(\.id) == ["anomaly-today", "digest-old"])
    }

    @Test func recapIsEmptyWhenNothingHasBeenSeen() throws {
        let recap = visibility(hour: 9).caughtUpItems(from: [
            digest(id: "digest-unread", date: "2026-05-24", period: .morning),
            news(),
        ])

        #expect(recap.isEmpty)
    }

    /// A submitted check-in is something that happened, not something that can
    /// be un-seen — and the feed has no way to reopen one.
    @Test func recapIncludesCompletedCheckInsForReadOnlyReview() throws {
        let recap = visibility(hour: 13).caughtUpItems(from: [
            checkIn(.morning, completed: true, caughtUpAt: .now),
        ])

        #expect(recap.count == 1)
    }

    private func anomaly(id: String, acknowledgedAt: Date? = nil, caughtUpAt: Date? = nil) -> UpToSpeedItem {
        UpToSpeedItem(
            id: id,
            type: .anomaly,
            caughtUpAt: caughtUpAt,
            payload: .anomaly(Anomaly(
                id: id,
                metric: "oura.had_readiness_score.percent",
                displayName: "Readiness Score",
                domain: "health",
                acknowledgedAt: acknowledgedAt
            ))
        )
    }

    private func visibility(hour: Int) -> UpToSpeedVisibility {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 5
        components.day = 24
        components.hour = hour
        components.minute = 0

        return UpToSpeedVisibility(
            now: components.date!,
            calendar: calendar
        )
    }

    private func timestamp(hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(
            year: 2026,
            month: 5,
            day: 24,
            hour: hour,
            minute: minute
        ))!
    }

    private func checkIn(
        _ period: CheckInPeriod,
        completed: Bool,
        caughtUpAt: Date? = nil
    ) -> UpToSpeedItem {
        UpToSpeedItem(
            id: "\(period.rawValue):2026-05-24",
            type: .checkIn,
            caughtUpAt: caughtUpAt,
            payload: .checkIn(UpToSpeedCheckInSummary(
                period: period,
                date: "2026-05-24",
                completed: completed
            ))
        )
    }

    private func digest(
        id: String,
        date: String,
        period: FlintDigestPeriod,
        caughtUpAt: Date? = nil
    ) -> UpToSpeedItem {
        UpToSpeedItem(
            id: id,
            type: .flintDigest,
            caughtUpAt: caughtUpAt,
            payload: .flintDigest(UpToSpeedFlintDigestSummary(
                date: date,
                period: period,
                title: nil,
                summary: nil,
                blockCount: 0,
                unansweredQuestionCount: 0
            ))
        )
    }

    private func news() -> UpToSpeedItem {
        UpToSpeedItem(
            id: "news-1",
            type: .newsSummary,
            caughtUpAt: nil,
            payload: .newsSummary(NewsSummary(
                title: "News",
                source: "fetch"
            ))
        )
    }
}
