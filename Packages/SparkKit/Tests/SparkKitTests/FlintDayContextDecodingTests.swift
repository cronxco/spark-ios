import Foundation
import Testing
@testable import SparkKit

@Suite("FlintDayContext decoding")
struct FlintDayContextDecodingTests {
    @Test("decodes a flint_day_context block with calendar, birthdays, and weather")
    func decodesFullBlock() throws {
        let json = """
        {
          "id": "block-1",
          "block_type": "flint_day_context",
          "title": "Today at a glance",
          "time": "2026-09-10T07:27:00+00:00",
          "day_context": {
            "calendar": [
              { "title": "Will · Office", "all_day": false, "start": "2026-09-10T09:00:00+01:00", "person": "will" },
              { "title": "Dan · Office", "all_day": false, "start": "2026-09-10T09:00:00+01:00", "person": "dan" }
            ],
            "birthdays": [
              { "title": "Daniel's birthday" }
            ],
            "weather": { "location": "London", "condition": "Overcast", "temp_high_c": 20, "rain_probability_pct": 38 }
          }
        }
        """

        let block = try makeDecoder().decode(FlintDigestBlock.self, from: Data(json.utf8))
        let dayContext = try #require(block.dayContext)

        #expect(dayContext.calendar.count == 2)
        #expect(dayContext.calendar[0].person == .will)
        #expect(dayContext.calendar[0].allDay == false)
        #expect(dayContext.calendar[1].person == .dan)
        #expect(dayContext.birthdays.count == 1)
        #expect(dayContext.birthdays[0].title == "Daniel's birthday")
        #expect(dayContext.weather?.condition == "Overcast")
        #expect(dayContext.weather?.tempHighC == 20)
        #expect(dayContext.weather?.rainProbabilityPct == 38)
        #expect(block.content == nil)
    }

    @Test("an unrecognised or missing person decodes as .will, not a decode failure")
    func defaultsUnknownPersonToWill() throws {
        let json = """
        {
          "id": "block-2",
          "block_type": "flint_day_context",
          "title": "Today at a glance",
          "day_context": {
            "calendar": [
              { "title": "Team standup" },
              { "title": "Weird entry", "person": "someone_else" }
            ]
          }
        }
        """

        let block = try makeDecoder().decode(FlintDigestBlock.self, from: Data(json.utf8))
        let dayContext = try #require(block.dayContext)

        #expect(dayContext.calendar.count == 2)
        #expect(dayContext.calendar[0].person == .will)
        #expect(dayContext.calendar[1].person == .will)
    }

    @Test("a block with no day_context decodes to nil")
    func decodesNilWhenAbsent() throws {
        let json = """
        {
          "id": "block-3",
          "block_type": "flint_editorial_note",
          "title": "Editorial note",
          "content": "Some prose."
        }
        """

        let block = try makeDecoder().decode(FlintDigestBlock.self, from: Data(json.utf8))
        #expect(block.dayContext == nil)
    }

    @Test("missing calendar/birthdays default to empty arrays")
    func defaultsMissingArraysToEmpty() throws {
        let json = """
        {
          "id": "block-4",
          "block_type": "flint_day_context",
          "title": "Today at a glance",
          "day_context": { "weather": { "condition": "Sunny" } }
        }
        """

        let block = try makeDecoder().decode(FlintDigestBlock.self, from: Data(json.utf8))
        let dayContext = try #require(block.dayContext)

        #expect(dayContext.calendar.isEmpty)
        #expect(dayContext.birthdays.isEmpty)
        #expect(dayContext.weather?.condition == "Sunny")
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }

    @Test("date decodes and drives describesToday")
    func dateDecodes() throws {
        let json = Data("""
        {"date":"2026-09-13","calendar":[],"birthdays":[],"weather":null}
        """.utf8)
        let context = try JSONDecoder().decode(FlintDayContext.self, from: json)

        #expect(context.date == "2026-09-13")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        let onTheDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 20)))
        let dayBefore = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 20)))

        #expect(context.describesToday(now: onTheDay, calendar: calendar))
        #expect(!context.describesToday(now: dayBefore, calendar: calendar))
    }

    /// A bare `yyyy-MM-dd` has no time zone, so it has to be resolved in the
    /// same calendar it is compared against. Resolving it in the device's zone
    /// and comparing it in another put the reader on the wrong side of local
    /// midnight — "Tomorrow" showing as "Today", and a yesterday recap
    /// appearing beside tomorrow's plans.
    @Test("the day resolves in the calendar it is compared against")
    func dayResolvesInTheGivenTimeZone() throws {
        let context = FlintDayContext(date: "2026-09-13")

        var farWest = Calendar(identifier: .gregorian)
        farWest.timeZone = try #require(TimeZone(identifier: "Pacific/Midway"))
        let lateOnTheDay = try #require(
            farWest.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 23))
        )
        #expect(context.describesToday(now: lateOnTheDay, calendar: farWest))

        var farEast = Calendar(identifier: .gregorian)
        farEast.timeZone = try #require(TimeZone(identifier: "Pacific/Kiritimati"))
        let earlyOnTheDay = try #require(
            farEast.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 1))
        )
        #expect(context.describesToday(now: earlyOnTheDay, calendar: farEast))

        // Same calendar day, different instants — which is the whole point.
        #expect(context.day(in: farWest) != context.day(in: farEast))
    }

    /// Every digest written before the field existed described the day it was
    /// written on, so silence has to mean today — not "some other day".
    @Test("a context with no date counts as today")
    func absentDateCountsAsToday() throws {
        let json = Data("""
        {"calendar":[],"birthdays":[]}
        """.utf8)
        let context = try JSONDecoder().decode(FlintDayContext.self, from: json)

        #expect(context.date == nil)
        #expect(context.day() == nil)
        #expect(context.describesToday(now: .now, calendar: .current))
    }

    @Test("an unparseable date counts as today rather than relabelling the day")
    func malformedDateCountsAsToday() throws {
        let json = Data(#"{"date":"not-a-date","calendar":[]}"#.utf8)
        let context = try JSONDecoder().decode(FlintDayContext.self, from: json)

        #expect(context.day() == nil)
        #expect(context.describesToday(now: .now, calendar: .current))
    }

    /// `"weather": {}` decodes to a non-nil value carrying nothing, which the
    /// opener would otherwise render as an empty tile with a default glyph.
    @Test("a weather object with no fields set has no content")
    func emptyWeatherHasNoContent() throws {
        let empty = try JSONDecoder().decode(
            FlintDayContext.self,
            from: Data(#"{"weather":{}}"#.utf8)
        )
        #expect(empty.weather != nil)
        #expect(empty.weather?.hasContent == false)

        let blankStrings = FlintDayContextWeather(location: "", condition: "")
        #expect(!blankStrings.hasContent)

        #expect(FlintDayContextWeather(condition: "Overcast").hasContent)
        #expect(FlintDayContextWeather(tempHighC: 20).hasContent)
        #expect(FlintDayContextWeather(rainProbabilityPct: 0).hasContent)
    }
}
