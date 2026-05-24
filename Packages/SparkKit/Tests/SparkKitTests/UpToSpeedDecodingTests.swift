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
