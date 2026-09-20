import Foundation
import SparkKit
import Testing

@testable import Spark

@Suite("Day metric readings")
struct MetricReadingTests {
    /// The backend publishes `vs_baseline_pct`, not the baseline, so the card
    /// has to recover it. Sleep 70 at −14.2% is a baseline of about 82, which
    /// is where the tick belongs.
    @Test("recovers the baseline the percentage was measured against")
    func recoversBaseline() throws {
        let reading = MetricReading(value: 70, vsBaselinePct: -14.2)
        let baseline = try #require(reading.baseline)
        #expect(abs(baseline - 81.58) < 0.05)
    }

    @Test("no percentage means no baseline and no tick")
    func noBaseline() {
        let reading = MetricReading(value: 70, vsBaselinePct: nil)
        #expect(reading.baseline == nil)
        #expect(reading.scoreBar.baseline == nil)
        #expect(reading.deltaText == nil)
    }

    @Test("formats the delta with a real minus sign")
    func formatsDelta() {
        #expect(MetricReading(value: 86, vsBaselinePct: 10.6).deltaText == "+11%")
        #expect(MetricReading(value: 70, vsBaselinePct: -14.2).deltaText == "\u{2212}14%")
        #expect(MetricReading(value: 77, vsBaselinePct: -0.4).deltaText == "on baseline")
    }

    @Test("a score draws on a fixed scale so two score cards are comparable")
    func scoreBar() throws {
        let bar = MetricReading(value: 80, vsBaselinePct: -2).scoreBar
        #expect(abs(try #require(bar.fill) - 0.8) < 0.001)
        #expect(abs(try #require(bar.baseline) - 0.816) < 0.005)
    }

    @Test("an open-ended quantity scales so today and its baseline both fit")
    func quantityBar() throws {
        let bar = MetricReading(value: 4426, vsBaselinePct: -48.1).quantityBar
        let fill = try #require(bar.fill)
        let baseline = try #require(bar.baseline)
        #expect(fill < baseline)
        #expect(baseline <= 1)
        #expect(fill > 0)
    }

    @Test("a zero baseline cannot be divided by and draws nothing")
    func degenerateBaseline() {
        #expect(MetricReading(value: 10, vsBaselinePct: -100).baseline == nil)
        #expect(MetricReading(value: 0, vsBaselinePct: -48).quantityBar.fill == nil)
    }
}

@Suite("Day metric grid")
struct DayMetricsTests {
    private func summary(
        health: [String: AnyCodable]? = nil,
        activity: [String: AnyCodable]? = nil,
        money: [String: AnyCodable]? = nil,
        sync: DaySummary.SyncStatus = .init()
    ) -> DaySummary {
        DaySummary(
            date: "2026-09-19",
            timezone: "Europe/London",
            syncStatus: sync,
            sections: .init(
                health: health.map { AnyCodable(.object($0)) },
                activity: activity.map { AnyCodable(.object($0)) },
                money: money.map { AnyCodable(.object($0)) },
                media: nil,
                knowledge: nil
            ),
            anomalies: []
        )
    }

    private func card(_ metrics: DayMetrics, _ id: String) -> DayMetrics.Card? {
        metrics.cards.first { $0.id == id }
    }

    @Test("always renders four cards, in one order")
    func fourCards() {
        let metrics = DayMetrics(summary: nil)
        #expect(metrics.cards.map(\.id) == ["sleep", "activity", "readiness", "money"])
    }

    @Test("a day with nothing in it waits rather than reporting zeroes")
    func emptyDayWaits() {
        let metrics = DayMetrics(summary: nil)
        for card in metrics.cards {
            guard case .waiting = card.reading else {
                Issue.record("\(card.id) should be waiting on an empty day")
                continue
            }
            #expect(card.fill == nil)
        }
    }

    /// The case this design exists for: Apple Health has not written since
    /// midnight, so the day reads 211 steps. Reporting that as a −97% fall
    /// would be wrong, and it is what the shipping screen did.
    @Test("a stale service waits instead of reporting its partial figures")
    func staleServiceWaits() throws {
        let sync = DaySummary.SyncStatus(
            services: ["apple_health": .init(eventCount: 13, lastEventTime: .now, coverage: "partial")]
        )
        let metrics = DayMetrics(
            summary: summary(
                activity: [
                    "steps": AnyCodable(.object([
                        "value": AnyCodable(.int(211)),
                        "vs_baseline_pct": AnyCodable(.double(-97.5)),
                        "is_anomaly": AnyCodable(.bool(true)),
                    ])),
                ],
                sync: sync
            )
        )

        let activity = try #require(card(metrics, "activity"))
        guard case .waiting(let reason) = activity.reading else {
            Issue.record("activity should be waiting while Apple Health is partial")
            return
        }
        #expect(reason.contains("Apple Health"))
        #expect(activity.fill == nil)
        #expect(activity.primary.value == nil)
    }

    @Test("a service that has reported is read normally")
    func freshServiceReads() throws {
        let sync = DaySummary.SyncStatus(
            services: ["apple_health": .init(eventCount: 27, lastEventTime: .now)]
        )
        let metrics = DayMetrics(
            summary: summary(
                health: [
                    "activity_score": AnyCodable(.object([
                        "score": AnyCodable(.int(90)),
                        "vs_baseline_pct": AnyCodable(.double(6)),
                    ])),
                ],
                activity: [
                    "steps": AnyCodable(.object(["value": AnyCodable(.int(4426))])),
                    "active_energy_kcal": AnyCodable(.object(["value": AnyCodable(.double(354.065))])),
                ],
                sync: sync
            )
        )

        let activity = try #require(card(metrics, "activity"))
        guard case .value(let text, let delta) = activity.reading else {
            Issue.record("activity should read its score")
            return
        }
        #expect(text == "90")
        #expect(delta == "+6%")
        #expect(activity.primary.value == "4,426")
        #expect(activity.secondary.value == "354 kcal")
    }

    @Test("sleep falls back to REM when the night has no stage breakdown yet")
    func sleepFallsBackToREM() throws {
        let metrics = DayMetrics(
            summary: summary(
                health: [
                    "sleep_score": AnyCodable(.object([
                        "score": AnyCodable(.int(80)),
                        "vs_baseline_pct": AnyCodable(.double(-2)),
                        "contributors": AnyCodable(.object(["Rem Sleep": AnyCodable(.int(97))])),
                    ])),
                ]
            )
        )

        let sleep = try #require(card(metrics, "sleep"))
        #expect(sleep.primary.value == nil)
        #expect(sleep.secondary.label == "REM")
        #expect(sleep.secondary.value == "97")
    }

    @Test("spend has no published baseline, so its bar stays empty")
    func spendHasNoBaseline() throws {
        let metrics = DayMetrics(
            summary: summary(money: ["total_spend": AnyCodable(.double(5.26))]),
            money: MoneyContext(
                pinnedAccountLabel: "Current Account",
                pinnedAccountBalance: "£3,180",
                netWorthChange: "+£1,204"
            )
        )

        let money = try #require(card(metrics, "money"))
        #expect(money.fill == nil)
        #expect(money.baseline == nil)
        #expect(money.primary.label == "Current Account")
        #expect(money.secondary.value == "+£1,204")
    }
}
