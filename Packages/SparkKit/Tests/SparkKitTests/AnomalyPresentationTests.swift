import Foundation
import Testing

@testable import SparkKit

@Suite("Anomaly presentation")
struct AnomalyPresentationTests {
    private func heartRate(current: Double = 76.88, baseline: Double = 98.39) -> Anomaly {
        Anomaly(
            id: "hr",
            metric: "oura.had_heart_rate.bpm",
            displayName: "Heart Rate",
            direction: "down",
            currentValue: current,
            baselineValue: baseline,
            domain: "health",
            unit: "bpm",
            currentDisplay: "77 bpm",
            baselineWindowDays: 90
        )
    }

    @Test func namesReadInSentenceCase() {
        #expect(heartRate().sentenceCaseName == "Heart rate")
        let hrv = Anomaly(id: "hrv", displayName: "Heart Rate HRV")
        #expect(hrv.sentenceCaseName == "Heart rate HRV")
    }

    @Test func heroSplitsTheUnitFromTheValue() {
        let parts = heartRate().heroParts
        #expect(parts.value == "77")
        #expect(parts.unit == "bpm")

        let money = Anomaly(id: "m", currentValue: 2082.23, currentDisplay: "£2,082.23")
        #expect(money.heroParts.value == "£2,082.23")
        #expect(money.heroParts.unit == nil)
    }

    @Test func comparisonFollowsTheDesignLanguageShape() {
        #expect(heartRate().comparisonText == "22bpm below 90d trend")
        #expect(heartRate().movement == .below)

        let spend = Anomaly(id: "s", currentValue: 120, baselineValue: 82, unit: "GBP")
        #expect(spend.comparisonText == "£38 above 90d trend")
    }

    @Test func bandedScoresCountBands() {
        let resilience = Anomaly(id: "r", currentValue: 2, baselineValue: 4, isOrdinal: true, baselineWindowDays: 30)
        #expect(resilience.comparisonText == "2 bands below 30d trend")
    }

    @Test func missingValuesGiveNoComparison() {
        #expect(Anomaly(id: "x", currentValue: 3).comparisonText == nil)
    }
}
