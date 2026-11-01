import Foundation
import Testing

@testable import Spark

@Suite("Money plan formatting")
struct MoneyPlanFormatTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }

    private static let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 9))!

    @Test("amounts always carry two decimals, refunds a plus")
    func amounts() {
        #expect(MoneyPlanFormat.amount(2480) == "£24.80")
        #expect(MoneyPlanFormat.amount(150_000) == "£1,500.00")
        #expect(MoneyPlanFormat.amount(-1_047_015) == "-£10,470.15")
        #expect(MoneyPlanFormat.amount(500, signed: true) == "+£5.00")
    }

    @Test("the hero splits pounds from pence")
    func hero() {
        let parts = MoneyPlanFormat.heroParts(-1_047_015)
        #expect(parts.whole == "-£10,470")
        #expect(parts.fraction == ".15")
        #expect(MoneyPlanFormat.heroParts(5).fraction == ".05")
    }

    @Test("bills due tomorrow say so")
    func due() {
        #expect(MoneyPlanFormat.dueLabel("2026-11-01", now: Self.now, calendar: Self.calendar) == "Tomorrow, Sunday 1 November")
        #expect(MoneyPlanFormat.dueLabel("2026-10-31", now: Self.now, calendar: Self.calendar) == "Today, Saturday 31 October")
        #expect(MoneyPlanFormat.dueLabel("2026-11-05", now: Self.now, calendar: Self.calendar) == "Thursday 5 November")
    }

    @Test("the payday line counts the days, and admits a guess")
    func payday() {
        #expect(
            MoneyPlanFormat.paydayLine("2026-11-29", known: true, now: Self.now, calendar: Self.calendar)
                == "Payday is Sunday 29 November, in 29 days"
        )
        #expect(
            MoneyPlanFormat.paydayLine("2026-11-29", known: false, now: Self.now, calendar: Self.calendar)
                == "Counting to Sunday 29 November, in 29 days"
        )
        #expect(MoneyPlanFormat.paydayLine(nil, known: true, now: Self.now, calendar: Self.calendar) == nil)
    }

    @Test("short days and month initials")
    func days() {
        #expect(MoneyPlanFormat.shortDay("2026-10-08", calendar: Self.calendar) == "8 Oct")
        #expect(MoneyPlanFormat.monthInitial("2026-09") == "S")
        #expect(MoneyPlanFormat.monthName("2026-09") == "September")
    }
}
