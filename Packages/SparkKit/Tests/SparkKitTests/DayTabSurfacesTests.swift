import Foundation
import Testing
@testable import SparkKit

@Suite("Digest opener")
struct FlintDigestOpenerTests {
    private func digest(summary: String?) -> FlintDigest {
        FlintDigest(
            eventID: "e1",
            date: "2026-09-20",
            period: .morning,
            kind: .briefing,
            title: "Morning Digest",
            summary: summary,
            blockCount: 0,
            blocks: []
        )
    }

    @Test("skips the greeting and the capitalised section heading")
    func skipsGreetingAndHeading() {
        let summary = """
        Good Sunday morning.

        DRIVING THE DAY

        Today's genuinely quiet — nothing on your calendar.
        """
        #expect(digest(summary: summary).opener == "Today's genuinely quiet — nothing on your calendar.")
    }

    @Test("takes the first bullet of an evening cheat sheet, without its marker")
    func takesFirstBullet() {
        let summary = """
        Good Saturday evening.

        SATURDAY CHEAT SHEET

        — Dinner at Brother Marcus in Victoria ahead of Shamilton with Soph.
        — Sleep read soft again at 70.
        """
        #expect(
            digest(summary: summary).opener
                == "Dinner at Brother Marcus in Victoria ahead of Shamilton with Soph."
        )
    }

    @Test("strips markdown emphasis the card does not render")
    func stripsEmphasis() {
        let summary = "Good morning.\n\nA **£2,508.27** transfer landed."
        #expect(digest(summary: summary).opener == "A £2,508.27 transfer landed.")
    }

    @Test("does not mistake prose beginning with good for a greeting")
    func keepsGoodNews() {
        let summary = "Good news on the mortgage came through this afternoon, and it changes the picture."
        #expect(digest(summary: summary).opener == summary)
    }

    @Test("cuts at the last whole sentence that fits")
    func truncatesOnSentence() {
        let summary = "One sentence that is reasonably long and carries the lede. "
            + "A second sentence that pushes the paragraph past the limit entirely."
        let opener = FlintDigest.opener(from: summary, limit: 70)
        #expect(opener == "One sentence that is reasonably long and carries the lede.")
    }

    @Test("no summary means no card")
    func noSummary() {
        #expect(digest(summary: nil).opener == nil)
        #expect(digest(summary: "Good morning.").opener == nil)
    }
}

@Suite("Thread watching-for")
struct FlintTopicWatchTests {
    @Test("takes the closing sentence, which names what would move the thread")
    func takesClosingSentence() {
        let content = "Reported US–Iran hostilities remain unresolved. "
            + "The decisive next developments are a G7 decision on reserves."
        #expect(
            FlintTopic.watchingFor(in: content)
                == "The decisive next developments are a G7 decision on reserves."
        )
    }

    @Test("reaches back a sentence when the closer is too short to carry anything")
    func reachesBackForShortCloser() {
        let content = "Will has booked train travel to Edinburgh with Dan in October. It is booked."
        #expect(
            FlintTopic.watchingFor(in: content)
                == "Will has booked train travel to Edinburgh with Dan in October. It is booked."
        )
    }

    @Test("truncates a very long closer")
    func truncates() {
        let long = String(repeating: "word ", count: 80) + "end."
        let result = FlintTopic.watchingFor(in: long, limit: 40)
        #expect(result?.count ?? 0 <= 41)
        #expect(result?.hasSuffix("…") == true)
    }

    @Test("no content means nothing to watch")
    func noContent() {
        #expect(FlintTopic.watchingFor(in: nil) == nil)
        #expect(FlintTopic.watchingFor(in: "   ") == nil)
    }
}

@Suite("Day summary sync status")
struct DaySummarySyncStatusTests {
    /// The shape `DaySummaryService` actually sends. The model used to declare
    /// a flat `{up_to_date, stale, last_event_at}` object, which decoded every
    /// field to nil against this payload — so a service hours behind never
    /// reached the UI.
    private let payload = """
    {
      "date": "2026-09-20",
      "timezone": "UTC",
      "sync_status": {
        "oura": {
          "event_count": 6,
          "last_event_time": "2026-09-20T00:00:00Z",
          "actions": ["had_sleep_score"]
        },
        "apple_health": {
          "event_count": 13,
          "last_event_time": "2026-09-20T00:00:00Z",
          "actions": ["had_step_count"],
          "coverage": "partial"
        }
      },
      "sections": {},
      "anomalies": []
    }
    """

    private func decode() throws -> DaySummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DaySummary.self, from: Data(payload.utf8))
    }

    @Test("decodes the per-service map")
    func decodesServices() throws {
        let summary = try decode()
        #expect(summary.syncStatus.services.count == 2)
        #expect(summary.syncStatus.services["oura"]?.eventCount == 6)
        #expect(summary.syncStatus.services["apple_health"]?.coverage == "partial")
        #expect(summary.syncStatus.services["apple_health"]?.isPartial == true)
        #expect(summary.syncStatus.services["oura"]?.isPartial == false)
    }

    @Test("a service the backend calls partial is behind whatever its clock says")
    func partialIsBehind() throws {
        let summary = try decode()
        let justNow = Date(timeIntervalSince1970: 1_789_000_000)
        #expect(summary.syncStatus.isBehind("apple_health", now: justNow) == true)
    }

    @Test("a service that has gone quiet past the threshold is behind")
    func quietIsBehind() throws {
        let summary = try decode()
        let lastWrite = try #require(summary.syncStatus.lastWrite("oura"))
        #expect(summary.syncStatus.isBehind("oura", now: lastWrite.addingTimeInterval(3600)) == false)
        #expect(summary.syncStatus.isBehind("oura", now: lastWrite.addingTimeInterval(5 * 3600)) == true)
    }

    @Test("a service that has not written at all counts as behind")
    func missingIsBehind() throws {
        let summary = try decode()
        #expect(summary.syncStatus.isBehind("monzo") == true)
    }

    @Test("round-trips through encoding")
    func roundTrips() throws {
        let summary = try decode()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let again = try decoder.decode(DaySummary.self, from: encoder.encode(summary))
        #expect(again.syncStatus.services["apple_health"]?.coverage == "partial")
        #expect(again.syncStatus.services["oura"]?.eventCount == 6)
    }
}
