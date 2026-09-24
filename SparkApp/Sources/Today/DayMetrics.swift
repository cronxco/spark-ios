import Foundation
import SparkKit
import SparkUI
import SwiftUI

/// One figure from the day summary, with the backend's own baseline
/// comparison turned into something a metric card can draw.
///
/// The backend publishes `vs_baseline_pct` rather than the baseline itself, so
/// the baseline is recovered from it: `value = baseline × (1 + pct / 100)`.
/// That is exact for every metric the summary carries a percentage for, spend
/// included now that it has a day-level baseline of its own.
struct MetricReading: Sendable, Hashable {
    let value: Double
    let vsBaselinePct: Double?
    let isAnomaly: Bool

    init?(_ payload: [String: AnyCodable]?, key: String = "value") {
        guard let payload else { return nil }
        guard let value = payload[key]?.doubleValue ?? payload["value"]?.doubleValue else { return nil }
        self.value = value
        self.vsBaselinePct = payload["vs_baseline_pct"]?.doubleValue
        self.isAnomaly = payload["is_anomaly"]?.boolValue ?? false
    }

    init(value: Double, vsBaselinePct: Double? = nil, isAnomaly: Bool = false) {
        self.value = value
        self.vsBaselinePct = vsBaselinePct
        self.isAnomaly = isAnomaly
    }

    var baseline: Double? {
        guard let vsBaselinePct else { return nil }
        let factor = 1 + vsBaselinePct / 100
        guard abs(factor) > 0.0001 else { return nil }
        return value / factor
    }

    /// "+11%", "−14%", or "on baseline" when the day sits on it.
    var deltaText: String? {
        guard let vsBaselinePct else { return nil }
        let rounded = (vsBaselinePct).rounded()
        if abs(rounded) < 1 { return "on baseline" }
        let sign = rounded > 0 ? "+" : "\u{2212}"
        return "\(sign)\(Int(abs(rounded)))%"
    }

    /// A score out of 100 draws on a fixed scale, so two score cards side by
    /// side are directly comparable.
    var scoreBar: BarGeometry {
        BarGeometry(fill: value / 100, baseline: baseline.map { $0 / 100 })
    }

    /// An open-ended quantity has no natural ceiling, so the scale is set by
    /// whichever of today and the baseline is larger, with headroom so a big
    /// overshoot still reads as an overshoot rather than a full bar.
    var quantityBar: BarGeometry {
        guard let baseline, baseline > 0 else { return .empty }
        let scale = max(value, baseline) * 1.2
        guard scale > 0 else { return .empty }
        return BarGeometry(fill: value / scale, baseline: baseline / scale)
    }
}

/// Where today and its baseline sit on the bar, 0…1 each. `nil` on either
/// means there is nothing to draw — the card keeps its height regardless.
struct BarGeometry: Sendable, Hashable {
    let fill: Double?
    let baseline: Double?

    static let empty = BarGeometry(fill: nil, baseline: nil)
}

/// What the money card can say beyond the day's spend. None of it comes from
/// the day summary: balances are their own resource, and there is no "pinned"
/// flag on an account yet, so the current account stands in for one.
struct MoneyContext: Sendable, Hashable {
    var pinnedAccountLabel: String?
    var pinnedAccountBalance: String?
    var netWorthChange: String?

    static let empty = MoneyContext()
}

/// The four cards on the Day tab's metric grid, built once so the view is
/// only laying out.
struct DayMetrics: Sendable {
    struct Card: Sendable, Identifiable {
        let id: String
        let label: String
        let tint: Color
        let reading: BaselineMetricCard.Reading
        let fill: Double?
        let baseline: Double?
        let isFlagged: Bool
        let primary: BaselineMetricCard.Supporting
        let secondary: BaselineMetricCard.Supporting
    }

    let cards: [Card]


    init(summary: DaySummary?, money: MoneyContext = .empty) {
        let health = summary?.sections.health?.objectValue
        let activity = summary?.sections.activity?.objectValue
        let moneySection = summary?.sections.money?.objectValue

        // Apple Health writes in bursts; before the first one lands, the day
        // reads as near-zero steps. Whether it is behind is the server's call
        // — `stale`, or `coverage: partial` — so there is no clock arithmetic
        // here. Say so rather than reporting a fall.
        let activityIsBehind = summary?.syncStatus.isBehind("apple_health") ?? false

        cards = [
            Self.sleepCard(health),
            Self.activityCard(health: health, activity: activity, isBehind: activityIsBehind),
            Self.readinessCard(health: health, activity: activity),
            Self.moneyCard(moneySection, context: money),
        ]
    }

    // MARK: - Cards

    private static func sleepCard(_ health: [String: AnyCodable]?) -> Card {
        let scoreObject = health?["sleep_score"]?.objectValue
        let score = MetricReading(scoreObject, key: "score")
        let duration = health?["sleep_duration"]?.objectValue
        let contributors = scoreObject?["contributors"]?.objectValue

        let seconds = duration?["duration_seconds"]?.intValue
        let efficiency = contributors?["Efficiency"]?.intValue
        let rem = contributors?["Rem Sleep"]?.intValue

        let bar = score?.scoreBar ?? .empty
        let reading: BaselineMetricCard.Reading
        if let score {
            reading = .value(Self.whole(score.value), delta: score.deltaText)
        } else {
            reading = .waiting("Waiting on Oura")
        }

        return Card(
            id: "sleep",
            label: "Sleep",
            tint: .domainHealth,
            reading: reading,
            fill: bar.fill,
            baseline: bar.baseline,
            isFlagged: false,
            primary: .init("Duration", seconds.map(Self.duration)),
            // Efficiency is the contributor that survives a short night; REM
            // stands in for it on a day Oura has scored but not yet broken
            // down into stages.
            secondary: efficiency.map { BaselineMetricCard.Supporting("Efficiency", "\($0)%") }
                ?? BaselineMetricCard.Supporting("REM", rem.map { "\($0)" })
        )
    }

    private static func activityCard(
        health: [String: AnyCodable]?,
        activity: [String: AnyCodable]?,
        isBehind: Bool
    ) -> Card {
        // Oura files the activity score under health; the raw counts are
        // Apple Health's, under activity.
        let score = MetricReading(health?["activity_score"]?.objectValue, key: "score")
        let steps = MetricReading(activity?["steps"]?.objectValue)
        let energy = MetricReading(activity?["active_energy_kcal"]?.objectValue)

        if isBehind {
            return Card(
                id: "activity",
                label: "Activity",
                tint: .domainActivity,
                reading: .waiting("Waiting on Apple Health"),
                fill: nil,
                baseline: nil,
                isFlagged: false,
                primary: .init("Steps", nil),
                secondary: .init("Active", nil)
            )
        }

        let bar: BarGeometry
        let reading: BaselineMetricCard.Reading
        if let score {
            bar = score.scoreBar
            reading = .value(Self.whole(score.value), delta: score.deltaText)
        } else if let steps {
            // No Oura score for the day yet; steps still say something.
            bar = steps.quantityBar
            reading = .value(Self.count(steps.value), delta: steps.deltaText)
        } else {
            // Not behind, and nothing reported: a quiet morning, or no
            // activity integration at all. Neither is something to wait on.
            bar = .empty
            reading = .waiting("No activity yet")
        }

        return Card(
            id: "activity",
            label: "Activity",
            tint: .domainActivity,
            reading: reading,
            fill: bar.fill,
            baseline: bar.baseline,
            isFlagged: false,
            primary: .init("Steps", steps.map { Self.count($0.value) }),
            secondary: .init("Active", energy.map { "\(Int($0.value.rounded())) kcal" })
        )
    }

    private static func readinessCard(
        health: [String: AnyCodable]?,
        activity: [String: AnyCodable]?
    ) -> Card {
        let score = MetricReading(health?["readiness_score"]?.objectValue, key: "score")
        let restingHR = MetricReading(activity?["resting_heart_rate"]?.objectValue)
        let stress = health?["stress"]?.objectValue?["band"]?.stringValue

        let bar = score?.scoreBar ?? .empty
        let reading: BaselineMetricCard.Reading
        if let score {
            reading = .value(Self.whole(score.value), delta: score.deltaText)
        } else {
            reading = .waiting("Waiting on Oura")
        }

        return Card(
            id: "readiness",
            label: "Readiness",
            tint: .domainHealth,
            reading: reading,
            fill: bar.fill,
            baseline: bar.baseline,
            isFlagged: false,
            primary: .init("Resting HR", restingHR.map { "\(Int($0.value.rounded())) bpm" }),
            secondary: .init("Stress", stress)
        )
    }

    private static func moneyCard(
        _ money: [String: AnyCodable]?,
        context: MoneyContext
    ) -> Card {
        // `total_spend` is outflow to third parties only. Money moved between
        // the user's own accounts is `internal_transfers` and is not spend —
        // the day a savings transfer landed used to read as £2,621 spent.
        let currency = money?["transactions"]?.arrayValue?
            .first?.objectValue?["currency"]?.stringValue ?? "GBP"

        // The spend baseline is published under its own flat key, not as a
        // nested `vs_baseline_pct`, because `total_spend` is a number rather
        // than an object. When there is not yet enough history the server says
        // so in `total_spend_baseline_unavailable_reason` and the key is absent.
        let spend: MetricReading?
        if let value = money?["total_spend"]?.doubleValue {
            spend = MetricReading(
                value: abs(value),
                vsBaselinePct: money?["total_spend_vs_baseline_pct"]?.doubleValue
            )
        } else {
            spend = nil
        }

        let reading: BaselineMetricCard.Reading
        if let spend {
            reading = .value(Self.currency(spend.value, code: currency), delta: spend.deltaText)
        } else {
            reading = .waiting("No spend today")
        }

        // An open-ended quantity: scaled so today and a typical day both fit.
        // No baseline yet leaves the track empty rather than inventing one.
        let bar = spend?.quantityBar ?? .empty

        // Not flagged. Ember is for a day the server calls anomalous, and the
        // money section does not publish that judgement for spend.
        return Card(
            id: "money",
            label: "Money",
            tint: .domainMoney,
            reading: reading,
            fill: bar.fill,
            baseline: bar.baseline,
            isFlagged: false,
            primary: .init(context.pinnedAccountLabel ?? "Balance", context.pinnedAccountBalance),
            secondary: .init("Net worth 1mo", context.netWorthChange)
        )
    }

    // MARK: - Formatting

    private static func whole(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    private static func count(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? whole(value)
    }

    private static func duration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    static func currency(_ amount: Double, code: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = amount >= 1000 ? 0 : 2
        return f.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}
