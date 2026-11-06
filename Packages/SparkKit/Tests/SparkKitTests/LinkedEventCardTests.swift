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
          "context": {"direction": "up", "valence": "good", "within_usual_range": true, "text": "35m above 30d avg", "mean": 26400},
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

    @Test("durations and counts sit on a bar against the 30d mean; scores do not")
    func meanBar() throws {
        let cards = try summary().linkedEvents

        #expect(cards[0].context?.mean == 26400)
        let fraction = try #require(cards[0].meanBarFraction)
        #expect(abs(fraction - 28500.0 / 39600.0) < 0.0001)
        #expect(cards[1].meanBarFraction == nil)
        #expect(EventKind.steps.drawsAgainstMean)
        #expect(EventKind.steps.heroUnit == "steps")
        #expect(EventKind.sleepDuration.heroUnit == nil)
        #expect(!EventKind.sleepScore.drawsAgainstMean)
        #expect(abs(LinkedEventCard.meanBarMarker - 2.0 / 3.0) < 0.0001)
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

    // MARK: Layouts (design language §7.3)

    private static let layoutsPayload = """
    {
      "date": "2026-11-05",
      "block_count": 0,
      "unanswered_question_count": 0,
      "linked_events": [
        {
          "kind": "google-calendar.had_event",
          "layout": "journey",
          "event": {"id": "d0303fe9-174b-445f-a6a9-6423cb3273c1", "time": "2026-11-05T08:10:00+00:00", "service": "google-calendar", "domain": "knowledge", "action": "had_event", "value": 255, "unit": "minutes"},
          "context": null,
          "at_digest": null,
          "details": {"flight": "BA2704", "from": "LGW", "to": "ACE", "route": "London to Lanzarote", "departs_at": "2026-11-05T08:10:00+00:00", "arrives_at": "2026-11-05T12:25:00+00:00", "departs_local": "08:10", "departs_zone": "GMT", "arrives_local": "12:25", "arrives_zone": "WET", "duration_minutes": 255},
          "answer": null
        },
        {
          "kind": "gocardless.payment_to",
          "layout": "payment",
          "event": {"id": "0fe98669-3178-4859-8239-a5888543a915", "time": "2026-11-04T12:58:53+00:00", "service": "gocardless", "domain": "money", "action": "payment_to", "value": 159, "unit": "GBP", "display_value": "£159.00"},
          "context": null,
          "at_digest": null,
          "details": {"merchant": "Criterion Theatre Trust - Box Office", "account": "British Airways Premium Plus", "pending": true, "refund": false, "week": {"amounts": [420, 350, 15900], "index": 2, "caption": "Largest this week"}},
          "answer": {"answer": "Theatre tickets or booking", "note": "Redcliffe, Sat 30 January with Dan"}
        },
        {
          "kind": "newsletter.received_post",
          "layout": "reading",
          "event": {"id": "4c14bc4e-0fa2-450b-b7cc-6115215a465b", "time": "2026-11-05T07:01:16+00:00", "service": "newsletter", "domain": "knowledge", "action": "received_post"},
          "context": null,
          "at_digest": null,
          "details": {"publication": "Klement on Investing", "headline": "China is decoupling from the West", "url": null, "read_minutes": 2, "takeaways": ["**China's trade is shifting:** imports come from China-aligned countries.", "**Brazil and Russia gained.**"]},
          "answer": null
        },
        {
          "kind": "oura.had_sleep_score",
          "layout": "something_new",
          "event": {"id": "c0720298-cb3c-4812-bca3-7b35767eee6f", "time": "2026-11-05T00:00:00+00:00", "service": "oura", "domain": "health", "action": "had_sleep_score", "value": 81, "unit": "percent"}
        },
        {
          "kind": "monzo.bank_transfer_from",
          "layout": "transfer",
          "event": {"id": "5fd356ae-ef8b-477b-880c-b9feb1aa966b", "time": "2026-11-05T09:02:54+00:00", "service": "monzo", "domain": "money", "action": "bank_transfer_from", "value": 1500, "unit": "GBP", "display_value": "£1,500.00"},
          "context": null,
          "at_digest": null,
          "details": {"direction": "in", "counterparty": "Mortgage", "account": "Current Account", "pending": false},
          "answer": null
        },
        {
          "kind": "monzo.pot_transfer_to",
          "layout": "transfer",
          "event": {"id": "7a1c2e30-5b8d-4f61-9e2a-0c3d4b5a6f70", "time": "2026-11-05T10:00:00+00:00", "service": "monzo", "domain": "money", "action": "pot_transfer_to", "value": 50, "unit": "GBP"},
          "details": {"direction": "out", "counterparty": "Holiday", "account": "Current Account", "pending": true}
        }
      ]
    }
    """

    private func layoutCards() throws -> [LinkedEventCard] {
        try Self.decoder.decode(UpToSpeedFlintDigestSummary.self, from: Data(Self.layoutsPayload.utf8)).linkedEvents
    }

    @Test("a flight decodes as a journey card with its route and times")
    func journeyLayout() throws {
        let flight = try layoutCards()[0]

        #expect(flight.layout == .journey)
        #expect(flight.layout.isWide)
        #expect(flight.label == "Flight BA2704")
        #expect(flight.details?.from == "LGW")
        #expect(flight.details?.to == "ACE")
        #expect(flight.details?.durationMinutes == 255)
        let departs = try #require(flight.details?.departsAt)
        #expect(flight.details?.flightProgress(at: departs.addingTimeInterval(-60)) == nil)
        let halfway = try #require(flight.details?.flightProgress(at: departs.addingTimeInterval(255 * 30)))
        #expect(abs(halfway - 0.5) < 0.0001)
    }

    @Test("a payment decodes with its merchant, week and the reader's answer")
    func paymentLayout() throws {
        let payment = try layoutCards()[1]

        #expect(payment.layout == .payment)
        #expect(payment.label == "Payment")
        #expect(payment.details?.pending == true)
        #expect(payment.details?.week?.index == 2)
        #expect(payment.details?.week?.amounts == [420, 350, 15900])
        #expect(payment.answer?.text == "Redcliffe, Sat 30 January with Dan")
        #expect(LinkedEventCard.Answer(answer: "A gift", note: "  ").text == "A gift")
    }

    @Test("a transfer decodes with its direction, the other party and the account")
    func transferLayout() throws {
        let cards = try layoutCards()
        let incoming = cards[4]
        let outgoing = cards[5]

        #expect(incoming.layout == .transfer)
        #expect(incoming.layout.isWide)
        #expect(incoming.label == "Transfer in")
        #expect(incoming.details?.counterparty == "Mortgage")
        #expect(incoming.details?.transferAccountText == "into Current Account")
        #expect(incoming.details?.week == nil)

        #expect(outgoing.label == "Transfer out")
        #expect(outgoing.details?.transferAccountText == "from Current Account")
        #expect(outgoing.details?.pending == true)
    }

    @Test("an article decodes as a reading card with its takeaways")
    func readingLayout() throws {
        let article = try layoutCards()[2]

        #expect(article.layout == .reading)
        #expect(article.label == "Klement on Investing")
        #expect(article.details?.headline == "China is decoupling from the West")
        #expect(article.details?.takeaways?.count == 2)
        #expect(article.liveValue == nil)
    }

    @Test("an unknown or missing layout falls back to the metric card")
    func unknownLayout() throws {
        let cards = try layoutCards()
        #expect(cards[3].layout == .metric)
        #expect(!cards[3].layout.isWide)
        #expect(try summary().linkedEvents[0].layout == .metric)
    }

    @Test("a decoded card round-trips through the cache")
    func roundTrip() throws {
        let payment = try layoutCards()[1]
        let data = try JSONEncoder().encode(payment)
        let decoded = try JSONDecoder().decode(LinkedEventCard.self, from: data)
        #expect(decoded.layout == .payment)
        #expect(decoded.details?.merchant == payment.details?.merchant)
        #expect(decoded.answer == payment.answer)
    }
}
