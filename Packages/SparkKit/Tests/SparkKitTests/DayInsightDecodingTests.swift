import Foundation
import Testing
@testable import SparkKit

@Suite("DayInsight decoding")
struct DayInsightDecodingTests {
    private func summary(insights: String?) -> Data {
        let field = insights.map { ", \"insights\": \($0)" } ?? ""
        return Data("""
        { "date": "2026-11-05", "timezone": "Europe/London", "sync_status": {}, "sections": {}, "anomalies": []\(field) }
        """.utf8)
    }

    @Test("an older backend without insights still decodes")
    func absentInsights() throws {
        let decoded = try JSONDecoder().decode(DaySummary.self, from: summary(insights: nil))
        #expect(decoded.insights == nil)
    }

    @Test("a period insight reads as a daily average against the last 4 weeks")
    func periodSentence() throws {
        let json = """
        [{ "id": "a1", "metric": "apple_health.had_step_count.count", "display_name": "Step Count",
           "kind": "insight_period", "direction": "up", "valence": "good",
           "current_value": 12583.45, "baseline_value": 7901.64,
           "current_display": "12,583 count", "delta_display": "4,682 count",
           "comparison": "4w trend", "day_label": null,
           "start_date": "2026-10-30", "end_date": "2026-11-05" }]
        """
        let decoded = try JSONDecoder().decode(DaySummary.self, from: summary(insights: json))
        let insight = try #require(decoded.insights?.first)
        #expect(insight.valence == .good)
        #expect(!insight.isDown)
        #expect(insight.sentence == "12,583 a day, 4,682 more than the last 4 weeks")
    }

    @Test("a typical insight names the day only when the server did")
    func typicalSentence() throws {
        let withDay = DayInsight(
            id: "t1", kind: "insight_typical", direction: "down", valence: .bad,
            currentDisplay: "62%", deltaDisplay: "14%", comparison: "usual", dayLabel: "a Thursday"
        )
        #expect(withDay.sentence == "62%, 14% less than usual for a Thursday")

        let withoutDay = DayInsight(
            id: "t2", kind: "insight_typical", direction: "up", currentDisplay: "£432", deltaDisplay: "£364"
        )
        #expect(withoutDay.sentence == "£432, £364 more than usual")
    }

    @Test("an unknown direction is worded neutrally")
    func unknownDirection() {
        let insight = DayInsight(id: "u1", kind: "insight_typical", currentDisplay: "62%", deltaDisplay: "14%")
        #expect(!insight.isUp && !insight.isDown)
        #expect(insight.sentence == "62%, 14% different from usual")
    }

    @Test("missing display strings fall back to the raw numbers")
    func fallbacks() throws {
        let json = #"[{ "kind": "insight_shift", "direction": "down", "current_value": 71.5, "metric": "m", "end_date": "2026-11-05" }]"#
        let decoded = try JSONDecoder().decode(DaySummary.self, from: summary(insights: json))
        let insight = try #require(decoded.insights?.first)
        #expect(insight.id == "m|insight_shift|2026-11-05")
        #expect(insight.valence == .neutral)
        #expect(insight.sentence == "71.5 a day this week, lower than usual")
    }
}
