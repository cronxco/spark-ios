import Foundation
import Testing
@testable import SparkIntelligence
import SparkKit

@Suite("Spoken day summary")
struct SpokenSummaryTests {
    private func snapshot(health: String, activity: String, money: String) throws -> TodayIntentSnapshot {
        let json = """
        {
          "date": "2026-10-17",
          "timezone": "Europe/London",
          "sync_status": { "up_to_date": true, "stale": [] },
          "sections": {
            "health": \(health),
            "activity": \(activity),
            "money": \(money),
            "media": null,
            "knowledge": null
          },
          "anomalies": []
        }
        """
        let summary = try JSONDecoder().decode(DaySummary.self, from: Data(json.utf8))
        return TodayIntentSnapshot(summary: summary)
    }

    @Test("an empty day says there is nothing to report")
    func emptyDay() throws {
        let snapshot = try snapshot(health: "null", activity: "null", money: "null")
        #expect(snapshot.spokenSummary == "Nothing to report for today yet.")
    }

    @Test("a full day reads sleep, steps and spend in order")
    func fullDay() throws {
        let snapshot = try snapshot(
            health: #"{ "sleep_score": { "score": 79 }, "sleep_duration": { "duration_seconds": 28080 } }"#,
            activity: #"{ "steps": { "value": 8400, "goal": 10000 } }"#,
            money: #"{ "total_spend": 24.5, "transactions": [{ "currency": "GBP" }] }"#
        )
        let text = snapshot.spokenSummary
        #expect(text.hasPrefix("You slept 7 hours and 48 minutes with a sleep score of 79."))
        #expect(text.contains("You've taken 8400 steps."))
        #expect(text.contains("You've spent"))
    }
}
