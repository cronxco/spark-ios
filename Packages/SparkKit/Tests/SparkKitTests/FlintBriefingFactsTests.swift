import Foundation
import Testing
@testable import SparkKit

@Suite("Flint briefing facts")
struct FlintBriefingFactsTests {
    @Test("maps key briefing sections into concise prompt facts")
    func mapsSections() {
        let summary = DaySummary(
            date: "2026-05-07",
            timezone: "Europe/London",
            syncStatus: .init(upToDate: true, stale: [], lastEventAt: nil),
            sections: .init(
                health: .init(.object([
                    "sleep_score": .init(.object(["score": .init(.int(82))])),
                    "sleep_duration": .init(.object(["duration_seconds": .init(.int(27_000))])),
                ])),
                activity: .init(.object([
                    "steps": .init(.object(["value": .init(.int(8_400)), "goal": .init(.int(10_000))])),
                ])),
                money: .init(.object([
                    "total_spend": .init(.double(24.5)),
                ])),
                media: nil,
                knowledge: nil
            ),
            anomalies: []
        )

        let facts = FlintBriefingFacts(summary: summary)

        #expect(facts.promptText.contains("Date: 2026-05-07"))
        #expect(facts.promptText.contains("Health:"))
        #expect(facts.promptText.contains("sleep score"))
        #expect(facts.promptText.contains("Activity:"))
        #expect(facts.promptText.contains("Money:"))
        #expect(facts.promptText.contains("Anomalies: none reported"))
    }

    @Test("fallback note includes anomalies as watchouts")
    func fallbackUsesAnomalies() {
        let summary = DaySummary(
            date: "2026-05-07",
            timezone: "Europe/London",
            syncStatus: .init(upToDate: false, stale: ["healthkit"], lastEventAt: nil),
            sections: .init(health: nil, activity: nil, money: nil, media: nil, knowledge: nil),
            anomalies: [
                Anomaly(
                    id: "resting-heart-rate",
                    metric: "resting_heart_rate",
                    displayName: "Resting heart rate",
                    direction: "up",
                    deviation: 0.18,
                    streakDays: 2
                ),
            ]
        )

        let note = FlintBriefingFacts(summary: summary).fallbackNote

        #expect(note.watchouts.contains { $0.contains("Resting heart rate") })
        #expect(note.suggestedActions.contains { $0.contains("watchouts") })
    }
}

