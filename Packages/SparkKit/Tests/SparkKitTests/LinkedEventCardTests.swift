import Foundation
import Testing
@testable import SparkKit

@Suite("Linked event cards")
struct LinkedEventCardTests {
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let sleepID = "d5dccb37-140b-4eae-b2b8-5b94fe8e660a"
    private static let scoreID = "77ec44eb-52da-4de7-8795-0a6f9bf3efdd"
    private static let readinessID = "131472c1-8d33-408d-adf5-852254e86b82"

    private static let payload = """
    {
      "date": "2026-10-28",
      "period": "morning",
      "kind": "briefing",
      "summary": "Oura has [7h55 of sleep](https://spark.cronx.co/events/\(sleepID)), a [sleep score of 66](https://spark.cronx.co/events/\(scoreID)) and [readiness at 88](https://spark.cronx.co/events/\(readinessID)).",
      "block_count": 2,
      "unanswered_question_count": 0,
      "linked_events": [
        {
          "kind": "oura.slept_for",
          "event": {"id": "\(sleepID)", "time": "2026-10-27T20:45:58+00:00", "service": "oura", "domain": "health", "action": "slept_for", "value": 28500, "unit": "seconds", "display_value": "7h55m", "display_name": "Sleep"},
          "context": {"direction": "up", "valence": "good", "within_usual_range": true, "text": "12m above your 30-day usual"},
          "at_digest": null
        },
        {
          "kind": "oura.had_sleep_score",
          "event": {"id": "\(scoreID)", "time": "2026-10-28T00:00:00+00:00", "service": "oura", "domain": "health", "action": "had_sleep_score", "value": 80, "unit": "percent", "display_value": "80<span class=\\"text-[0.875em]\\">%</span>", "display_name": "Sleep Score"},
          "context": null,
          "at_digest": {"value": 66, "display_value": "66%"}
        },
        {
          "kind": "oura.had_readiness_score",
          "event": "not an event"
        }
      ]
    }
    """

    private func summary() throws -> UpToSpeedFlintDigestSummary {
        try Self.decoder.decode(UpToSpeedFlintDigestSummary.self, from: Data(Self.payload.utf8))
    }

    @Test("decodes linked events and drops a malformed one")
    func decodesLinkedEvents() throws {
        let cards = try summary().linkedEvents

        #expect(cards.map(\.id) == [Self.sleepID, Self.scoreID])
        #expect(cards[0].kind == .sleepDuration)
        #expect(cards[0].context?.withinUsualRange == true)
        #expect(cards[1].kind == .sleepScore)
        #expect(cards[1].atDigest?.value == 66)
    }

    @Test("payloads without linked events decode as empty")
    func missingLinkedEvents() throws {
        let legacy = try Self.decoder.decode(
            UpToSpeedFlintDigestSummary.self,
            from: Data(#"{"date": "2026-10-28", "block_count": 0, "unanswered_question_count": 0}"#.utf8)
        )
        #expect(legacy.linkedEvents.isEmpty)
    }

    @Test("cards follow the paragraph's own order and skip unresolved links")
    func paragraphOrder() throws {
        let cards = try summary().linkedEvents
        let paragraph = "A [score](https://spark.cronx.co/events/\(Self.scoreID)), then [sleep](/event/\(Self.sleepID)) and [readiness](https://spark.cronx.co/events/\(Self.readinessID))."

        #expect(LinkedEventCard.linkedEventIDs(in: paragraph) == [Self.scoreID, Self.sleepID, Self.readinessID])
        #expect(LinkedEventCard.cards(linkedFrom: paragraph, in: cards).map(\.id) == [Self.scoreID, Self.sleepID])
        #expect(LinkedEventCard.cards(linkedFrom: "No links here.", in: cards).isEmpty)
    }

    @Test("hero values follow the design language formats")
    func heroValues() throws {
        let cards = try summary().linkedEvents

        #expect(cards[0].heroValue == "7h 55m")
        #expect(cards[0].label == "Sleep")
        #expect(cards[1].heroValue == "80")
        #expect(cards[1].updatedFromText == "Updated from 66")
        #expect(cards[0].updatedFromText == nil)
    }

    @Test("durations read 7h 55m, 42m and 1m 05s")
    func durations() {
        #expect(EventKind.duration(seconds: 28500) == "7h 55m")
        #expect(EventKind.duration(seconds: 42 * 60) == "42m")
        #expect(EventKind.duration(seconds: 65) == "1m 05s")
        #expect(EventKind.duration(seconds: 7200) == "2h")
        #expect(EventKind.duration(seconds: 30) == "30s")
        #expect(EventKind.exerciseTime.heroValue(56, unit: "min", displayValue: nil) == "56m")
    }

    @Test("a missing value is a dash, never zero")
    func missingValue() {
        #expect(EventKind.sleepScore.heroValue(nil, unit: "percent", displayValue: nil) == "—")
        #expect(EventKind("x.y").heroValue(nil, unit: nil, displayValue: "12") == "—")
    }

    @Test("unknown kinds fall back to the server's display value without markup")
    func genericKind() {
        let kind = EventKind("monzo.card_payment_to")
        #expect(kind == .generic("monzo.card_payment_to"))
        #expect(kind.ringMaximum == nil)
        #expect(kind.shortLabel == nil)
        #expect(kind.heroValue(24.8, unit: "GBP", displayValue: "£24.80") == "£24.80")
        #expect(kind.heroValue(12, unit: nil, displayValue: "12<span>%</span>") == "12%")
    }
}
