import Foundation
import SparkKit
import SparkUI
import Testing

@testable import Spark

@Suite("Explore Health display")
struct HealthExploreDisplayTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(json.utf8))
    }

    @Test("a small change is neutral, a notable one takes its polarity")
    func comparisonTone() throws {
        // Resting heart rate 77 at +4.2%: up, but inside the usual range.
        let small = try #require(HealthDisplay.comparison(
            value: 77, vsBaselinePct: 4.2, higherIsBetter: false, status: "normal"
        ) { "\(Int($0.rounded()))bpm" })
        #expect(small.text == "3bpm above 90d trend")
        #expect(small.direction == .up)
        #expect(small.isGood == nil)

        // Steps 12,430 at +49.3% with no status: notable and good.
        let steps = try #require(HealthDisplay.comparison(
            value: 12430, vsBaselinePct: 49.3, higherIsBetter: true
        ) { HealthDisplay.amount($0, unit: "steps") })
        #expect(steps.text == "4,104 steps above 90d trend")
        #expect(steps.isGood == true)
    }

    @Test("formats durations and numbers per section 9")
    func formatting() {
        #expect(HealthDisplay.duration(minutes: 105) == "1h 45m")
        #expect(HealthDisplay.duration(minutes: 42) == "42m")
        #expect(HealthDisplay.number(8.756) == "8.8")
        #expect(HealthDisplay.number(48.315) == "48")
        #expect(HealthDisplay.number(12430) == "12,430")
        #expect(HealthDisplay.amount(3, unit: "bpm") == "3bpm")
        #expect(HealthDisplay.amount(3.94, unit: "years") == "4 years")
        #expect(HealthDisplay.amount(3.6, unit: "km") == "3.6km")
    }

    @Test("an ordinal reading shows its level, not its number")
    func ordinalRow() throws {
        let metric = try decode(HealthDashboard.BodyMetric.self, """
        {"id": "oura.had_resilience_score.resilience_level", "event_id": "evt", "label": "Resilience",
         "value": 4, "unit": "resilience_level", "vs_baseline_pct": null, "is_ordinal": true,
         "band": "Strong", "is_anomaly": false, "status": "normal"}
        """)
        let row = HealthDisplay.bodyRow(metric)
        #expect(row.value == "Strong")
        #expect(row.unit == nil)
        #expect(row.comparison == nil)
        #expect(row.context == "Oura")
        #expect(row.icon == .resilience)
    }

    @Test("a body metric picks its glyph and polarity from its action")
    func bodyRowKind() throws {
        let metric = try decode(HealthDashboard.BodyMetric.self, """
        {"id": "oura.had_cardiovascular_age.years", "event_id": "evt", "label": "Cardiovascular Age",
         "value": 43, "unit": "years", "vs_baseline_pct": 10.1, "is_anomaly": true, "status": "low"}
        """)
        let row = HealthDisplay.bodyRow(metric)
        #expect(row.value == "43")
        #expect(row.unit == " years")
        // Older is worse, and the backend marked it.
        #expect(row.comparison?.isGood == false)
        #expect(row.comparison?.text == "4 years above 90d trend")
    }

    @Test("scores trend as a line, totals as bars, with a one-deviation band")
    func trendStyle() throws {
        let trends = try decode([HealthDashboard.Trend].self, """
        [{"metric": "oura.had_readiness_score.percent", "label": "Readiness", "service": "oura",
          "action": "had_readiness_score", "unit": "percent", "range": {"from": "2026-10-30", "to": "2026-10-31"},
          "daily_values": [{"date": "2026-10-30", "value": 81}, {"date": "2026-10-31", "value": 83}],
          "baseline": {"mean": 80.34, "stddev": 8.51}},
         {"metric": "apple_health.had_active_energy.kcal", "label": "Active Energy", "service": "apple_health",
          "action": "had_active_energy", "unit": "kcal", "range": {"from": "2026-10-30", "to": "2026-10-31"},
          "daily_values": [{"date": "2026-10-30", "value": 687.8}, {"date": "2026-10-31", "value": null}],
          "baseline": {"mean": 475.76, "stddev": 159.68}}]
        """)
        let readiness = try #require(HealthDisplay.trendCard(trends[0], days: 7))
        #expect(readiness.style == .line)
        #expect(readiness.average == "82")
        let band = try #require(readiness.usualRange)
        #expect(abs(band.lowerBound - 71.83) < 0.01)

        let energy = try #require(HealthDisplay.trendCard(trends[1], days: 7))
        #expect(energy.style == .bars)
        // A missing day is a gap, not a zero.
        #expect(energy.points.count == 2)
        #expect(energy.points[1].value == nil)
        #expect(energy.average == "688")
    }
}
