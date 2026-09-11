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
}
