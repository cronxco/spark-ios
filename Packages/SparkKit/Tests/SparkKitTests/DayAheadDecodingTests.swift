import Foundation
import Testing
@testable import SparkKit

@Suite("DayAhead decoding")
struct DayAheadDecodingTests {
    private let fullDay = """
    {
      "date": "2026-10-11",
      "timezone": "Europe/London",
      "sync_status": {},
      "sections": {},
      "anomalies": [],
      "ahead": {
        "date": "2026-10-11",
        "headline": "2 things on, first at 09:00. Sam's birthday. Overcast, 14°, 60% chance of rain.",
        "digest_event_id": "digest-1",
        "weather": { "location": "London", "condition": "Overcast", "temp_high_c": 14.4, "rain_probability_pct": 60 },
        "first_commitment": { "title": "Office", "start": "2026-10-11T09:00:00+01:00" },
        "calendar": [
          { "title": "Office", "start": "2026-10-11T09:00:00+01:00", "end": "2026-10-11T17:00:00+01:00", "all_day": false,
            "location": "Kings Cross", "person": "both", "event_id": "event-1" },
          { "title": "Climbing", "start": "2026-10-11T19:00:00+01:00", "end": null, "all_day": false,
            "location": null, "person": "someone_new", "event_id": null }
        ],
        "birthdays": [{ "title": "Sam's birthday" }],
        "plan": [
          { "id": "b1", "title": "Book boiler service", "kind": "day_note", "done": false, "topic_id": null, "topic_title": null, "url": "https://docs.example/day" },
          { "id": "b2", "title": "Book physio", "kind": "topic_task", "done": true, "topic_id": "t1", "topic_title": "Marathon base", "url": null },
          { "id": "t1", "title": "Marathon base", "kind": "something_later", "done": false }
        ],
        "day_note_url": "https://docs.example/day",
        "sleep_target": {
          "wake_by": "2026-10-11T05:30:00+01:00", "bed_by": "2026-10-10T21:10:00+01:00",
          "sleep_need_minutes": 480, "typical_wake": "07:00", "early_start": true, "readiness_low_nights": 0
        }
      }
    }
    """

    @Test("decodes the ahead section of a future day's summary")
    func decodesAhead() throws {
        let summary = try JSONDecoder().decode(DaySummary.self, from: Data(fullDay.utf8))
        let ahead = try #require(summary.ahead)

        #expect(ahead.headline.hasPrefix("2 things on"))
        #expect(ahead.weather?.tempHighC == 14.4)
        #expect(ahead.calendar.count == 2)
        #expect(ahead.calendar[0].person == .both)
        #expect(ahead.calendar[0].eventId == "event-1")
        #expect(ahead.calendar[0].endDate != nil)
        #expect(ahead.calendar[1].person == nil, "an unknown attribution shows untagged")
        #expect(ahead.birthdays.map(\.title) == ["Sam's birthday"])
        #expect(ahead.plan.map(\.kind) == [.dayNote, .topicTask, .unknown])
        #expect(ahead.openPlanCount == 2)
        #expect(ahead.dayNoteURL?.absoluteString == "https://docs.example/day")
        #expect(ahead.sleepTarget?.sleepNeedMinutes == 480)
        #expect(ahead.sleepTarget?.earlyStart == true)
        #expect(ahead.firstCommitment?.startDate == ahead.calendar[0].startDate)
    }

    @Test("a past or present day has no ahead section")
    func absentAhead() throws {
        let json = """
        { "date": "2026-10-10", "timezone": "Europe/London", "sync_status": {}, "sections": {}, "anomalies": [] }
        """
        let summary = try JSONDecoder().decode(DaySummary.self, from: Data(json.utf8))
        #expect(summary.ahead == nil)
    }

    @Test("survives the day-summary cache round trip")
    func roundTripsThroughCache() throws {
        let summary = try JSONDecoder().decode(DaySummary.self, from: Data(fullDay.utf8))
        // Encoded the way the Today page persists it, decoded the way
        // `CachedDaySummary.decoded()` reads it back.
        let cached = CachedDaySummary(date: "2026-10-11", timezone: "Europe/London", payload: try JSONEncoder().encode(summary))
        let restored = try cached.decoded()

        #expect(restored.ahead == summary.ahead)
    }

    @Test("an empty ahead section decodes with empty lists")
    func emptyAhead() throws {
        let json = """
        { "date": "2026-10-11", "headline": "Nothing on the calendar.", "calendar": [], "birthdays": [], "plan": [],
          "weather": null, "first_commitment": null, "day_note_url": null, "sleep_target": null }
        """
        let ahead = try JSONDecoder().decode(DayAhead.self, from: Data(json.utf8))
        #expect(!ahead.hasSchedule)
        #expect(ahead.openPlanCount == 0)
        #expect(ahead.sleepTarget == nil)
    }
}
