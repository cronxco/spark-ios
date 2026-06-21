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

    @Test func keepsNonCheckInUnreadItemsAndMostRecentDigestOnly() throws {
        let visible = visibility(hour: 9).visibleUnreadItems(from: [
            digest(id: "digest-morning", date: "2026-05-24", period: .morning),
            digest(id: "digest-afternoon", date: "2026-05-24", period: .afternoon),
            news(),
        ])

        #expect(visible.map(\.id) == ["digest-afternoon", "news-1"])
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
        period: FlintDigestPeriod
    ) -> UpToSpeedItem {
        UpToSpeedItem(
            id: id,
            type: .flintDigest,
            caughtUpAt: nil,
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
