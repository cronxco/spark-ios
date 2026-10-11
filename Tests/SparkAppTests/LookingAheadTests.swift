import Foundation
import SparkKit
import Testing

@testable import Spark

@Suite("Looking ahead")
struct LookingAheadTests {
    @Test("an empty tomorrow earns no evening card")
    func emptyTomorrowHasNoCard() {
        let ahead = DayAhead(date: "2026-10-11", headline: "Nothing on the calendar.")
        #expect(TodayViewModel.worthAGlance(ahead) == nil)
    }

    @Test("a schedule, an open task or a bedtime target each earn the card")
    func contentEarnsCard() {
        let scheduled = DayAhead(date: "2026-10-11", headline: "1 thing on.", calendar: [.init(title: "parkrun")])
        let planned = DayAhead(date: "2026-10-11", headline: "1 task planned.", plan: [.init(id: "b1", title: "Boiler", kind: .dayNote)])
        let early = DayAhead(
            date: "2026-10-11",
            headline: "Nothing on the calendar.",
            sleepTarget: .init(wakeBy: "2026-10-11T05:30:00+01:00", bedBy: "2026-10-10T21:10:00+01:00", sleepNeedMinutes: 480)
        )

        #expect(TodayViewModel.worthAGlance(scheduled) != nil)
        #expect(TodayViewModel.worthAGlance(planned) != nil)
        #expect(TodayViewModel.worthAGlance(early) != nil)
    }

    @Test("a plan of only finished tasks is not worth a card")
    func finishedPlanHasNoCard() {
        let ahead = DayAhead(date: "2026-10-11", headline: "Nothing on the calendar.", plan: [.init(id: "b1", title: "Done", kind: .dayNote, done: true)])
        #expect(TodayViewModel.worthAGlance(ahead) == nil)
    }

    @Test("sleep durations read as hours and minutes")
    func sleepDuration() {
        #expect(SleepTargetCard.duration(minutes: 480) == "8h")
        #expect(SleepTargetCard.duration(minutes: 460) == "7h 40m")
    }
}
