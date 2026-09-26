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
        let fill = try #require(bar.fill)
        let baseline = try #require(bar.baseline)
        #expect(abs(fill - 0.8) < 0.001)
        #expect(abs(baseline - 0.816) < 0.005)
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

    @Test("spend draws against the server's day-level baseline")
    func spendDrawsAgainstBaseline() throws {
        // £106.89 against a typical day the server puts 58% higher.
        let metrics = DayMetrics(
            summary: summary(money: [
                "total_spend": AnyCodable(.double(106.89)),
                "internal_transfers": AnyCodable(.double(2560.27)),
                "total_spend_vs_baseline_pct": AnyCodable(.double(-36.8)),
            ])
        )

        let money = try #require(card(metrics, "money"))
        guard case .value(let text, let delta) = money.reading else {
            Issue.record("money should read its spend")
            return
        }
        // Spend, not the £2,560 that moved between the user's own accounts.
        #expect(text == "£106.89")
        #expect(delta == "\u{2212}37%")
        let fill = try #require(money.fill)
        let baseline = try #require(money.baseline)
        #expect(fill < baseline)
        #expect(money.isFlagged == false)
    }

    @Test("spend with too little history draws an empty track, not a guess")
    func spendWithoutHistory() throws {
        let metrics = DayMetrics(
            summary: summary(money: [
                "total_spend": AnyCodable(.double(24)),
                "total_spend_baseline_unavailable_reason": AnyCodable(.string("insufficient_history")),
            ])
        )
        let money = try #require(card(metrics, "money"))
        #expect(money.fill == nil)
        #expect(money.baseline == nil)
    }

    @Test("a stale service waits even when its day is not marked partial")
    func staleWithoutPartialWaits() throws {
        let sync = DaySummary.SyncStatus(
            services: ["apple_health": .init(eventCount: 4, lastEventTime: .now, stale: true)]
        )
        let metrics = DayMetrics(summary: summary(sync: sync))
        let activity = try #require(card(metrics, "activity"))
        guard case .waiting(let reason) = activity.reading else {
            Issue.record("activity should wait while the server calls Apple Health stale")
            return
        }
        #expect(reason.contains("Apple Health"))
    }

    @Test("an Oura score still reads while Apple Health is behind")
    func ouraScoreSurvivesPartialAppleHealth() throws {
        let sync = DaySummary.SyncStatus(
            services: ["apple_health": .init(eventCount: 13, lastEventTime: .now, coverage: "partial")]
        )
        let metrics = DayMetrics(
            summary: summary(
                health: [
                    "activity_score": AnyCodable(.object(["score": AnyCodable(.int(82))])),
                ],
                activity: [
                    "steps": AnyCodable(.object(["value": AnyCodable(.int(211))])),
                ],
                sync: sync
            )
        )

        let activity = try #require(card(metrics, "activity"))
        guard case .value(let text, _) = activity.reading else {
            Issue.record("activity should read Oura's score")
            return
        }
        #expect(text == "82")
        // Apple Health's own partial figures stay hidden.
        #expect(activity.primary.value == nil)
        #expect(activity.secondary.value == nil)
    }

    @Test("a score the server calls anomalous is drawn flagged")
    func anomalousScoresAreFlagged() throws {
        let metrics = DayMetrics(
            summary: summary(
                health: [
                    "sleep_score": AnyCodable(.object([
                        "score": AnyCodable(.int(38)),
                        "vs_baseline_pct": AnyCodable(.double(-53)),
                        "is_anomaly": AnyCodable(.bool(true)),
                    ])),
                    "readiness_score": AnyCodable(.object([
                        "score": AnyCodable(.int(61)),
                        "vs_baseline_pct": AnyCodable(.double(-21.1)),
                        "is_anomaly": AnyCodable(.bool(false)),
                    ])),
                ]
            )
        )

        #expect(try #require(card(metrics, "sleep")).isFlagged == true)
        #expect(try #require(card(metrics, "readiness")).isFlagged == false)
    }

    @Test("sleep efficiency is Oura's measured percentage, not the contributor rating")
    func sleepEfficiencyIsMeasured() throws {
        let contributors = AnyCodable(.object(["Efficiency": AnyCodable(.int(65))]))
        let measured = DayMetrics(
            summary: summary(health: [
                "sleep_score": AnyCodable(.object([
                    "score": AnyCodable(.int(38)),
                    "contributors": contributors,
                ])),
                "sleep_duration": AnyCodable(.object([
                    "duration_seconds": AnyCodable(.int(25110)),
                    "efficiency_pct": AnyCodable(.int(69)),
                ])),
            ])
        )
        let sleep = try #require(card(measured, "sleep"))
        #expect(sleep.primary.value == "6h 58m")
        #expect(sleep.secondary.label == "Efficiency")
        #expect(sleep.secondary.value == "69%")

        // Without the measured figure, the 0–100 rating is shown bare.
        let rated = DayMetrics(
            summary: summary(health: [
                "sleep_score": AnyCodable(.object([
                    "score": AnyCodable(.int(38)),
                    "contributors": contributors,
                ])),
            ])
        )
        #expect(try #require(card(rated, "sleep")).secondary.value == "65")
    }

    @Test("a day with nothing spent carries no percentage")
    func zeroSpendHasNoDelta() throws {
        // An older server still sends −100% for a zero day.
        let metrics = DayMetrics(
            summary: summary(money: [
                "total_spend": AnyCodable(.int(0)),
                "internal_transfers": AnyCodable(.double(5.34)),
                "total_spend_vs_baseline_pct": AnyCodable(.int(-100)),
            ])
        )
        let money = try #require(card(metrics, "money"))
        guard case .value(let text, let delta) = money.reading else {
            Issue.record("money should read its spend")
            return
        }
        #expect(text == "£0.00")
        #expect(delta == nil)
    }

    @Test("Apple Health whose day is complete reads even if called stale")
    func completeAppleHealthReads() throws {
        let sync = DaySummary.SyncStatus(
            services: ["apple_health": .init(eventCount: 26, lastEventTime: .now, coverage: "complete", stale: true)]
        )
        let metrics = DayMetrics(
            summary: summary(
                activity: [
                    "steps": AnyCodable(.object([
                        "value": AnyCodable(.int(8064)),
                        "vs_baseline_pct": AnyCodable(.double(-5.6)),
                    ])),
                    "active_energy_kcal": AnyCodable(.object(["value": AnyCodable(.double(384.16))])),
                ],
                sync: sync
            )
        )

        let activity = try #require(card(metrics, "activity"))
        guard case .value(let text, let delta) = activity.reading else {
            Issue.record("activity should read its steps")
            return
        }
        #expect(text == "8,064")
        #expect(delta == "\u{2212}6%")
        #expect(activity.primary.value == "8,064")
        #expect(activity.secondary.value == "384 kcal")
    }

    @Test("an overdrawn balance rounds like a positive one")
    func negativeCurrencyRounds() {
        // Whole pounds at this size, whichever side of zero.
        #expect(!DayMetrics.currency(-3180, code: "GBP").contains("."))
        #expect(!DayMetrics.currency(3180, code: "GBP").contains("."))
    }

    @Test("no activity integration is a quiet card, not a wait")
    func noActivityIntegration() throws {
        let metrics = DayMetrics(summary: summary())
        let activity = try #require(card(metrics, "activity"))
        guard case .waiting(let reason) = activity.reading else {
            Issue.record("activity has nothing to show")
            return
        }
        #expect(!reason.contains("Apple Health"))
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


@Suite("Day tab money context")
@MainActor
struct DayMoneyContextTests {
    private func account(_ id: String, type: String, pinned: Bool?, balance: Double) -> MoneyAccount {
        MoneyAccount(
            id: id, title: id, kind: "monzo_account", accountType: type,
            currency: "GBP", isNegativeBalance: false, provider: nil,
            accountNumber: nil, sortCode: nil, interestRate: nil,
            startDate: nil, integrationId: nil, isPinned: pinned,
            latestBalance: try? JSONDecoder.day.decode(
                BalanceEntry.self,
                from: Data(#"{"id":"b-\#(id)","balance":\#(balance),"currency":"GBP","time":"2026-09-20T09:00:00Z","notes":null}"#.utf8)
            ),
            updatedAt: .now
        )
    }

    private func netWorth(change: Double) throws -> NetWorth {
        try JSONDecoder.day.decode(NetWorthResponse.self, from: Data("""
        {"data":{"total":48210.64,"currency":"GBP",
         "comparison":{"window":"1month","then":47006.46,"change":\(change),"change_pct":2.56}}}
        """.utf8)).data
    }

    @Test("the pinned account wins over the first current account")
    func pinnedWins() throws {
        let context = TodayViewModel.moneyContext(
            accounts: [
                account("Current", type: "current", pinned: false, balance: 3180),
                account("Joint", type: "joint", pinned: true, balance: 912.5),
            ],
            netWorth: try netWorth(change: 1204.18)
        )
        #expect(context.pinnedAccountLabel == "Joint")
        #expect(context.netWorthChange == "+£1,204")
    }

    @Test("with nothing pinned, the first current account stands in")
    func currentStandsIn() throws {
        let context = TodayViewModel.moneyContext(
            accounts: [
                account("Savings", type: "savings", pinned: nil, balance: 18400),
                account("Current", type: "current", pinned: nil, balance: 3180),
            ],
            netWorth: try netWorth(change: -250)
        )
        #expect(context.pinnedAccountLabel == "Current")
        #expect(context.netWorthChange == "\u{2212}£250.00")
    }

    @Test("a failed net-worth request still leaves the pinned balance")
    func netWorthMissing() {
        let context = TodayViewModel.moneyContext(
            accounts: [account("Current", type: "current", pinned: true, balance: 3180)],
            netWorth: nil
        )
        #expect(context.pinnedAccountLabel == "Current")
        #expect(context.pinnedAccountBalance != nil)
        #expect(context.netWorthChange == nil)
    }

    @Test("a failed refresh keeps what the card already showed")
    func failedRefreshKeepsPrevious() throws {
        let previous = MoneyContext(
            pinnedAccountLabel: "Current",
            pinnedAccountBalance: "£3,180",
            netWorthChange: "+£1,204"
        )

        // Both requests failed: nothing changes.
        #expect(TodayViewModel.mergedMoneyContext(previous: previous, accounts: nil, netWorth: nil) == previous)

        // Accounts failed, net worth arrived: only the comparison updates.
        let netWorthOnly = TodayViewModel.mergedMoneyContext(
            previous: previous,
            accounts: nil,
            netWorth: try netWorth(change: -250)
        )
        #expect(netWorthOnly.pinnedAccountBalance == "£3,180")
        #expect(netWorthOnly.netWorthChange == "\u{2212}£250.00")

        // Accounts succeeded but empty: the balance really has gone.
        let emptyAccounts = TodayViewModel.mergedMoneyContext(previous: previous, accounts: [], netWorth: nil)
        #expect(emptyAccounts.pinnedAccountBalance == nil)
        #expect(emptyAccounts.netWorthChange == "+£1,204")
    }

    @Test("a change under a pound reads as level")
    func level() throws {
        let context = TodayViewModel.moneyContext(accounts: [], netWorth: try netWorth(change: 0.4))
        #expect(context.netWorthChange == "level")
        #expect(context.pinnedAccountLabel == nil)
    }
}

@Suite("Day tab question stack")
@MainActor
struct DayQuestionOrderTests {
    private func question(_ id: String, _ status: String, asked: String) throws -> FlintQuestion {
        try JSONDecoder.day.decode(FlintQuestion.self, from: Data("""
        {"id":"\(id)","digest_id":"d","source_digest":{"local_date":null,"period":null},
         "status":"\(status)","question":"q","answer_options":null,"asked_at":"\(asked)",
         "effective_answer":null,"answer_history":[],"version":"v"}
        """.utf8))
    }

    @Test("open questions lead, answered ones follow, newest first within each")
    func ordering() throws {
        let ordered = TodayViewModel.orderForStack([
            try question("answered-old", "answered", asked: "2026-09-19T08:00:00Z"),
            try question("open-old", "open", asked: "2026-09-19T09:00:00Z"),
            try question("answered-new", "answered", asked: "2026-09-19T20:00:00Z"),
            try question("open-new", "open", asked: "2026-09-20T08:35:00Z"),
        ])
        #expect(ordered.map(\.id) == ["open-new", "open-old", "answered-new", "answered-old"])
    }
}

private extension JSONDecoder {
    static var day: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
