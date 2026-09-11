import Foundation
import Testing
@testable import SparkKit

@Suite("UpToSpeed decoding")
struct UpToSpeedDecodingTests {
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("decodes full mixed-type response")
    func decodesFullResponse() throws {
        let json = """
        {
          "items": [
            {
              "id": "event-uuid-1",
              "type": "flint_digest",
              "caught_up_at": null,
              "payload": {
                "date": "2026-05-23",
                "period": "morning",
                "title": "Morning Digest",
                "summary": "First paragraph.\\n\\nSecond paragraph.",
                "block_count": 3,
                "unanswered_question_count": 1
              }
            },
            {
              "id": "morning:2026-05-23",
              "type": "check_in",
              "caught_up_at": null,
              "payload": {
                "period": "morning",
                "date": "2026-05-23",
                "completed": false,
                "event_id": null
              }
            },
            {
              "id": "afternoon:2026-05-23",
              "type": "check_in",
              "caught_up_at": "2026-05-23T14:00:00Z",
              "payload": {
                "period": "afternoon",
                "date": "2026-05-23",
                "completed": true,
                "event_id": "event-abc"
              }
            },
            {
              "id": "trend-uuid-1",
              "type": "anomaly",
              "caught_up_at": null,
              "payload": {
                "metric": "oura.sleep_score",
                "display_name": "Sleep Score",
                "type": "low",
                "direction": "down",
                "current_value": 62.0,
                "baseline_value": 78.5,
                "deviation": -16.5,
                "streak_days": 3,
                "detected_at": "2026-05-23T06:00:00Z"
              }
            },
            {
              "id": "event-uuid-2",
              "type": "news_summary",
              "caught_up_at": null,
              "payload": {
                "title": "Article Title",
                "source": "fetch",
                "url": "https://example.com/article",
                "time": "2026-05-23T08:00:00Z",
                "tldr": "Short summary.",
                "summary": "Longer paragraph.",
                "key_takeaways": "Key points here."
              }
            }
          ]
        }
        """

        let response = try Self.decoder.decode(UpToSpeedResponse.self, from: Data(json.utf8))

        #expect(response.items.count == 5)

        // flint_digest
        let digest = response.items[0]
        #expect(digest.id == "event-uuid-1")
        #expect(digest.type == .flintDigest)
        #expect(digest.caughtUpAt == nil)
        if case .flintDigest(let s) = digest.payload {
            #expect(s.date == "2026-05-23")
            #expect(s.period == .morning)
            #expect(s.title == "Morning Digest")
            #expect(s.blockCount == 3)
            #expect(s.unansweredQuestionCount == 1)
        } else {
            Issue.record("Expected flintDigest payload")
        }

        // check_in (morning — incomplete)
        let morningCheckIn = response.items[1]
        #expect(morningCheckIn.id == "morning:2026-05-23")
        #expect(morningCheckIn.type == .checkIn)
        #expect(morningCheckIn.caughtUpAt == nil)
        if case .checkIn(let s) = morningCheckIn.payload {
            #expect(s.period == .morning)
            #expect(s.completed == false)
            #expect(s.eventId == nil)
        } else {
            Issue.record("Expected checkIn payload")
        }

        // check_in (afternoon — completed, caughtUpAt populated)
        let afternoonCheckIn = response.items[2]
        #expect(afternoonCheckIn.caughtUpAt != nil)
        if case .checkIn(let s) = afternoonCheckIn.payload {
            #expect(s.completed == true)
            #expect(s.eventId == "event-abc")
        } else {
            Issue.record("Expected checkIn payload")
        }

        // anomaly
        let anomaly = response.items[3]
        #expect(anomaly.id == "trend-uuid-1")
        #expect(anomaly.type == .anomaly)
        if case .anomaly(let a) = anomaly.payload {
            #expect(a.metric == "oura.sleep_score")
            #expect(a.displayName == "Sleep Score")
            #expect(a.currentValue == 62.0)
            #expect(a.streakDays == 3)
            // Absent fields must land on the safe defaults: an undeclared
            // metric is neutral, not alarming, and not ordinal.
            #expect(a.valence == .neutral)
            #expect(a.isOrdinal == false)
            #expect(a.domain == nil)
            #expect(a.acknowledgedAt == nil)
        } else {
            Issue.record("Expected anomaly payload")
        }

        // news_summary
        let news = response.items[4]
        #expect(news.id == "event-uuid-2")
        #expect(news.type == .newsSummary)
        if case .newsSummary(let n) = news.payload {
            #expect(n.title == "Article Title")
            #expect(n.source == "fetch")
            #expect(n.tldr == "Short summary.")
            #expect(n.keyTakeaways == "Key points here.")
        } else {
            Issue.record("Expected newsSummary payload")
        }
    }

    @Test("news_summary with nil fields decodes correctly")
    func decodesNewsSummaryWithNilFields() throws {
        let json = """
        {
          "items": [
            {
              "id": "e-1",
              "type": "news_summary",
              "caught_up_at": null,
              "payload": {
                "title": "Title",
                "source": "newsletter",
                "url": null,
                "time": null,
                "tldr": "Short.",
                "summary": null,
                "key_takeaways": null
              }
            }
          ]
        }
        """

        let response = try Self.decoder.decode(UpToSpeedResponse.self, from: Data(json.utf8))
        if case .newsSummary(let n) = response.items[0].payload {
            #expect(n.tldr == "Short.")
            #expect(n.summary == nil)
            #expect(n.keyTakeaways == nil)
            #expect(n.url == nil)
        } else {
            Issue.record("Expected newsSummary payload")
        }
    }

    @Test("flint_digest payload with null period decodes")
    func decodesDigestWithNullPeriod() throws {
        let json = """
        {
          "items": [
            {
              "id": "e-1",
              "type": "flint_digest",
              "caught_up_at": null,
              "payload": {
                "date": "2026-05-23",
                "period": null,
                "title": null,
                "summary": null,
                "block_count": 0,
                "unanswered_question_count": 0
              }
            }
          ]
        }
        """

        let response = try Self.decoder.decode(UpToSpeedResponse.self, from: Data(json.utf8))
        if case .flintDigest(let s) = response.items[0].payload {
            #expect(s.period == nil)
            #expect(s.title == nil)
        } else {
            Issue.record("Expected flintDigest payload")
        }
    }
}

@Suite("Flint digest summary payload")
struct FlintDigestSummaryDecodingTests {
    private func summary(_ json: String) throws -> UpToSpeedFlintDigestSummary {
        try JSONDecoder().decode(UpToSpeedFlintDigestSummary.self, from: Data(json.utf8))
    }

    @Test("decodes the declared kind")
    func decodesKind() throws {
        let roundup = try summary("""
        {"date": "2026-09-11", "title": "News roundup — Friday", "kind": "news_roundup",
         "block_count": 4, "unanswered_question_count": 0}
        """)
        #expect(roundup.kind == .newsRoundup)

        let reading = try summary("""
        {"date": "2026-09-11", "title": "Saved to read", "kind": "reading_list",
         "block_count": 0, "unanswered_question_count": 0}
        """)
        #expect(reading.kind == .readingList)
    }

    /// Responses predating the field must still decode, and a plain briefing is
    /// the safe reading — the client falls back to inspecting the content.
    @Test("an absent kind reads as a briefing")
    func absentKindIsBriefing() throws {
        let digest = try summary("""
        {"date": "2026-09-11", "title": "Morning Digest", "block_count": 2,
         "unanswered_question_count": 1}
        """)

        #expect(digest.kind == .briefing)
        #expect(digest.blockCount == 2)
        #expect(digest.unansweredQuestionCount == 1)
    }

    @Test("an unrecognised kind fails rather than being guessed at")
    func unknownKindFails() {
        #expect(throws: (any Error).self) {
            try summary("""
            {"date": "2026-09-11", "kind": "something_new", "block_count": 0,
             "unanswered_question_count": 0}
            """)
        }
    }
}

@Suite("Anomaly payload")
struct AnomalyPayloadDecodingTests {
    private func anomaly(_ json: String) throws -> Anomaly {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Anomaly.self, from: Data(json.utf8))
    }

    /// Everything the client needs to file and phrase an anomaly correctly —
    /// none of which the payload carried before.
    @Test("decodes domain, valence, ordinality and preformatted values")
    func decodesPresentationFields() throws {
        let a = try anomaly("""
        {
          "metric": "gocardless.had_balance.GBP",
          "display_name": "Balance Update",
          "domain": "money",
          "service": "gocardless",
          "unit": "GBP",
          "type": "anomaly_high",
          "direction": "up",
          "valence": "good",
          "is_ordinal": false,
          "current_value": 2082.23,
          "baseline_value": 241.68,
          "current_display": "£2,082.23",
          "baseline_display": "£241.68",
          "deviation": 3.76,
          "streak_days": 14,
          "detected_at": "2026-09-11T00:00:00Z",
          "acknowledged_at": null
        }
        """)

        #expect(a.domain == "money")
        #expect(a.valence == .good)
        #expect(a.isOrdinal == false)
        #expect(a.currentText == "£2,082.23")
        #expect(a.baselineText == "£241.68")
    }

    /// A banded score has no meaningful percentage change: "Adequate" is not
    /// 37% below "Solid".
    @Test("an ordinal metric reports its band and no percentage")
    func ordinalMetricHasNoPercentage() throws {
        let a = try anomaly("""
        {
          "metric": "oura.had_resilience_score.resilience_level",
          "display_name": "Resilience Level",
          "domain": "health",
          "valence": "bad",
          "is_ordinal": true,
          "current_value": 2,
          "baseline_value": 3.2,
          "current_display": "Adequate",
          "baseline_display": "Solid",
          "detected_at": "2026-09-11T00:00:00Z"
        }
        """)

        #expect(a.isOrdinal)
        #expect(a.currentText == "Adequate")
        #expect(a.percentChange == nil)
    }

    @Test("a continuous metric reports a percentage change")
    func continuousMetricHasPercentage() throws {
        let a = try anomaly("""
        {
          "metric": "oura.had_readiness_score.percent",
          "is_ordinal": false,
          "current_value": 50,
          "baseline_value": 100,
          "detected_at": "2026-09-11T00:00:00Z"
        }
        """)

        #expect(a.percentChange == -50)
    }

    @Test("falls back to the raw value when the server sent no display string")
    func fallsBackToRawValue() throws {
        let a = try anomaly("""
        {
          "metric": "oura.had_readiness_score.percent",
          "current_value": 78,
          "baseline_value": 85.5,
          "detected_at": "2026-09-11T00:00:00Z"
        }
        """)

        #expect(a.currentText == "78")
        #expect(a.baselineText == "85.5")
    }

    @Test("decodes the acknowledgement that marks an anomaly dismissed")
    func decodesAcknowledgement() throws {
        let a = try anomaly("""
        {
          "metric": "oura.had_sleep_score.percent",
          "detected_at": "2026-09-11T00:00:00Z",
          "acknowledged_at": "2026-09-11T09:30:00Z"
        }
        """)

        #expect(a.acknowledgedAt != nil)
    }
}
