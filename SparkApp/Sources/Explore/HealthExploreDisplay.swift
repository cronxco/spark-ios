import Foundation
import SparkKit
import SparkUI
import SwiftUI

/// Everything the Health page says about a reading, worked out once so the
/// view only lays out (`docs/design-language.md` sections 3.4, 8 and 9).
///
/// Metrics are matched on their exact action, never on substrings of a label.
enum HealthDisplay {
    /// The window the server's baselines cover
    /// (`MetricStatistic::DEFAULT_WINDOW_DAYS`), as on the Day tab.
    static let window = "90d"

    // MARK: - Registry

    /// How one health action is drawn: its glyph, domain and polarity.
    struct Kind: Equatable {
        let icon: SparkIcon
        let domain: String
        let higherIsBetter: Bool
        /// A 0–100 score, drawn as a ring or a line.
        let isScore: Bool

        static let fallback = Kind(icon: .health, domain: "health", higherIsBetter: true, isScore: false)
    }

    private static let kinds: [String: Kind] = [
        "had_readiness_score": Kind(icon: .score, domain: "health", higherIsBetter: true, isScore: true),
        "had_sleep_score": Kind(icon: .sleep, domain: "health", higherIsBetter: true, isScore: true),
        "had_heart_rate_variability": Kind(icon: .hrv, domain: "health", higherIsBetter: true, isScore: false),
        "had_resting_heart_rate": Kind(icon: .heartRate, domain: "health", higherIsBetter: false, isScore: false),
        "had_respiratory_rate": Kind(icon: .breathing, domain: "health", higherIsBetter: false, isScore: false),
        "had_spo2": Kind(icon: .bloodOxygen, domain: "health", higherIsBetter: true, isScore: false),
        "had_blood_oxygen_saturation": Kind(icon: .bloodOxygen, domain: "health", higherIsBetter: true, isScore: false),
        "had_apple_sleeping_wrist_temperature": Kind(icon: .health, domain: "health", higherIsBetter: false, isScore: false),
        "had_temperature_deviation": Kind(icon: .health, domain: "health", higherIsBetter: false, isScore: false),
        "had_stress_score": Kind(icon: .stress, domain: "health", higherIsBetter: false, isScore: false),
        "had_resilience_score": Kind(icon: .resilience, domain: "health", higherIsBetter: true, isScore: false),
        "had_cardiovascular_age": Kind(icon: .health, domain: "health", higherIsBetter: false, isScore: false),
        "had_vo2_max": Kind(icon: .breathing, domain: "health", higherIsBetter: true, isScore: false),
        "had_step_count": Kind(icon: .steps, domain: "activity", higherIsBetter: true, isScore: false),
        "had_walking_running_distance": Kind(icon: .distance, domain: "activity", higherIsBetter: true, isScore: false),
        "had_active_energy": Kind(icon: .energy, domain: "activity", higherIsBetter: true, isScore: false),
        "had_apple_exercise_time": Kind(icon: .duration, domain: "activity", higherIsBetter: true, isScore: false),
        "had_apple_stand_hour": Kind(icon: .stand, domain: "activity", higherIsBetter: true, isScore: false),
        "did_workout": Kind(icon: .energy, domain: "activity", higherIsBetter: true, isScore: false),
        "completed_workout": Kind(icon: .workout, domain: "activity", higherIsBetter: true, isScore: false),
    ]

    static func kind(action: String) -> Kind {
        kinds[action] ?? .fallback
    }

    /// A metric identifier is `service.action.unit`; the unit can hold dots.
    static func parts(of identifier: String) -> (service: String, action: String) {
        let pieces = identifier.split(separator: ".", maxSplits: 2).map(String.init)
        return (pieces.first ?? "", pieces.count > 1 ? pieces[1] : "")
    }

    static func serviceName(_ service: String) -> String {
        switch service {
        case "apple_health": "Apple Health"
        case "oura": "Oura"
        case "hevy": "Hevy"
        default: service.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    // MARK: - Comparison

    /// The comparison line for a reading against its baseline. A change is
    /// only coloured good or bad when it is notable: the backend's `status`
    /// for body metrics, or a 10% move for activity, the same threshold the
    /// backend uses. Anything smaller stays neutral.
    static func comparison(
        value: Double,
        vsBaselinePct: Double?,
        higherIsBetter: Bool,
        status: String? = nil,
        amount: (Double) -> String
    ) -> MetricComparison? {
        let reading = MetricReading(value: value, vsBaselinePct: vsBaselinePct)
        guard let comparison = reading.comparison(higherIsBetter: higherIsBetter, window: window, amount: amount) else {
            return nil
        }
        let isNotable: Bool
        if let status {
            isNotable = status != "normal"
        } else {
            isNotable = abs(vsBaselinePct ?? 0) >= 10
        }
        return MetricComparison(
            direction: comparison.direction,
            text: comparison.text,
            isGood: isNotable ? comparison.isGood : nil
        )
    }

    // MARK: - Numbers

    /// Grouped whole numbers from 10 up, one decimal below ("8.8", "48",
    /// "12,430").
    static func number(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = abs(value) < 10 ? 1 : 0
        formatter.minimumFractionDigits = 0
        let text = formatter.string(from: NSNumber(value: value)) ?? String(value)
        return text.replacingOccurrences(of: "-", with: "\u{2212}")
    }

    /// "1h 45m", "42m" (section 9).
    static func duration(minutes: Double) -> String {
        let total = Int(minutes.rounded())
        let hours = total / 60
        let rest = total % 60
        return hours > 0 ? "\(hours)h \(rest)m" : "\(rest)m"
    }

    static func duration(seconds: Double) -> String {
        duration(minutes: seconds / 60)
    }

    /// The unit as written beside a value. Word units keep a space before
    /// them; symbols attach.
    static func unit(_ raw: String?) -> String? {
        switch raw?.lowercased() {
        case nil, "", "steps", "count", "score", "stress_level", "resilience_level":
            nil
        case "percent", "%":
            "%"
        case "count/min", "bpm":
            "bpm"
        case "hours", "hour", "h":
            "h"
        case "min", "minutes":
            "m"
        case "years":
            " years"
        case "ml/(kg·min)", "ml/kg/min":
            " mL/kg/min"
        case "celsius", "degc", "°c":
            "°C"
        case "count/min (breaths)", "breaths/min":
            " breaths/min"
        default:
            " \(raw ?? "")"
        }
    }

    /// An amount with its unit, as a comparison writes it: "3bpm", "70kcal",
    /// "4 years", "4,105 steps".
    /// Whole numbers, except where a tenth matters (kilometres, degrees).
    static func amount(_ value: Double, unit raw: String?) -> String {
        switch raw?.lowercased() {
        case "steps":
            return "\(whole(value)) steps"
        case "min", "minutes":
            return duration(minutes: value)
        case "kcal":
            return "\(whole(value))kcal"
        case "km":
            return "\(number(value))km"
        case "celsius", "degc", "°c":
            return number(value) + "°C"
        default:
            return whole(value) + (unit(raw) ?? "")
        }
    }

    /// A grouped whole number: "4,104", "3".
    static func whole(_ value: Double) -> String {
        number(value.rounded())
    }

    // MARK: - Body metrics

    struct BodyRow: Identifiable, Equatable {
        let id: String
        let eventId: String
        let label: String
        let value: String
        let unit: String?
        let icon: SparkIcon
        let comparison: MetricComparison?
        /// Shown when there is no comparison: the source, or why it stands out.
        let context: String
        let isAnomaly: Bool

        var accessibilityLabel: String {
            [label, value + (unit ?? ""), comparison?.text ?? context].joined(separator: ", ")
        }
    }

    static func bodyRow(_ metric: HealthDashboard.BodyMetric) -> BodyRow {
        let parts = Self.parts(of: metric.id)
        let kind = Self.kind(action: parts.action)
        let source = serviceName(parts.service)

        if metric.isOrdinal == true {
            return BodyRow(
                id: metric.id,
                eventId: metric.eventId,
                label: metric.label,
                value: metric.band ?? metric.value.map(number) ?? "\u{2014}",
                unit: nil,
                icon: kind.icon,
                comparison: nil,
                context: metric.isAnomaly ? "Unusual for you" : source,
                isAnomaly: metric.isAnomaly
            )
        }

        let comparison = metric.value.flatMap { value in
            Self.comparison(
                value: value,
                vsBaselinePct: metric.vsBaselinePct,
                higherIsBetter: kind.higherIsBetter,
                status: metric.status
            ) { amount($0, unit: metric.unit) }
        }
        return BodyRow(
            id: metric.id,
            eventId: metric.eventId,
            label: metric.label,
            value: metric.value.map(number) ?? "\u{2014}",
            unit: unit(metric.unit),
            icon: kind.icon,
            comparison: comparison,
            context: source,
            isAnomaly: metric.isAnomaly
        )
    }

    // MARK: - Activity

    struct ActivityTile: Identifiable, Equatable {
        let id: String
        let label: String
        let value: String
        let unit: String?
        let icon: SparkIcon
        let bar: BarGeometry
        let comparison: MetricComparison?
        /// The trend metric this tile opens, when the dashboard has one.
        let metricIdentifier: String?

        var accessibilityLabel: String {
            [label, value + (unit ?? ""), comparison?.text].compactMap { $0 }.joined(separator: ", ")
        }
    }

    static func activityTiles(_ today: HealthDashboard.Today, trends: [HealthDashboard.Trend]) -> [ActivityTile] {
        func metric(_ action: String) -> String? {
            trends.first { $0.action == action && $0.service == "apple_health" }?.metric
        }
        func tile(
            _ id: String, _ label: String, action: String, quantity: HealthDashboard.Quantity?,
            value: (Double) -> String, unit: String?, amount: @escaping (Double) -> String
        ) -> ActivityTile? {
            guard let quantity, let raw = quantity.value else { return nil }
            let reading = MetricReading(value: raw, vsBaselinePct: quantity.vsBaselinePct)
            return ActivityTile(
                id: id,
                label: label,
                value: value(raw),
                unit: unit,
                icon: kind(action: action).icon,
                bar: reading.meanBar,
                comparison: comparison(value: raw, vsBaselinePct: quantity.vsBaselinePct, higherIsBetter: true, amount: amount),
                metricIdentifier: metric(action)
            )
        }

        return [
            tile("steps", "Steps", action: "had_step_count", quantity: today.steps,
                 value: number, unit: nil) { "\(whole($0)) steps" },
            tile("active_energy", "Active energy", action: "had_active_energy", quantity: today.activeEnergy,
                 value: number, unit: "kcal") { "\(whole($0))kcal" },
            tile("exercise", "Exercise", action: "had_apple_exercise_time", quantity: today.exercise,
                 value: { duration(minutes: $0) }, unit: nil) { duration(minutes: $0) },
            tile("distance", "Distance", action: "had_walking_running_distance", quantity: today.distance,
                 value: number, unit: "km") { "\(number($0))km" },
            tile("stand", "Stand", action: "had_apple_stand_hour", quantity: today.stand,
                 value: number, unit: "h") { "\(whole($0))h" },
        ].compactMap { $0 }
    }

    // MARK: - Workouts

    static func workoutIcon(_ workout: HealthDashboard.Workout) -> SparkIcon {
        if workout.kind == "strength" { return .workout }
        switch (workout.type ?? workout.title).lowercased() {
        case "walk", "walking", "hike", "hiking": return .steps
        default: return .activity
        }
    }

    /// The facts after a workout's title, spaced by a gap (section 9).
    static func workoutFacts(_ workout: HealthDashboard.Workout) -> [String] {
        var facts: [String] = []
        if workout.durationSeconds > 0 {
            facts.append(duration(seconds: workout.durationSeconds))
        }
        if let distance = workout.distance, let value = distance.value {
            facts.append("\(number(value)) \(distance.unit ?? "")".trimmingCharacters(in: .whitespaces))
        }
        if let volume = workout.volume, let value = volume.value {
            facts.append("\(number(value)) \(volume.unit ?? "kg")")
        }
        if let exercises = workout.exercises, !exercises.isEmpty {
            facts.append(exercises.count == 1 ? "1 exercise" : "\(exercises.count) exercises")
        }
        if let energy = workout.energyKcal, energy > 0 {
            facts.append("\(number(energy)) kcal")
        }
        return facts
    }

    // MARK: - Trends

    struct TrendCard: Identifiable {
        let id: String
        let label: String
        let icon: SparkIcon
        let domain: String
        let style: DailyTrendChart.Style
        let points: [DailyTrendChart.Point]
        let usualRange: ClosedRange<Double>?
        let average: String
        let unit: String?
        let latest: String?
        let comparison: MetricComparison?
        let rangeLabel: String

        var accessibilityLabel: String {
            [label, "\(rangeLabel) \(average)\(unit ?? "")", latest.map { "latest \($0)" }, comparison?.text]
                .compactMap { $0 }
                .joined(separator: ", ")
        }
    }

    static func trendCard(_ trend: HealthDashboard.Trend, days: Int) -> TrendCard? {
        let points = trend.dailyValues.compactMap { value -> DailyTrendChart.Point? in
            guard let date = dayFormatter.date(from: value.date) else { return nil }
            return DailyTrendChart.Point(date: date, value: value.value)
        }
        let values = points.compactMap(\.value)
        guard !values.isEmpty else { return nil }

        let kind = Self.kind(action: trend.action)
        let isMinutes = trend.unit == "min"
        let isScore = kind.isScore || trend.unit == "percent"
        let total: Double = values.reduce(0.0) { $0 + $1 }
        let mean: Double = total / Double(values.count)
        let format: (Double) -> String = { value in
            isMinutes ? Self.duration(minutes: value) : Self.number(value)
        }
        let suffix: String? = isMinutes ? nil : Self.unit(trend.unit)
        let baseline: Double? = trend.baseline?.mean

        var usualRange: ClosedRange<Double>?
        if let baseline, let deviation = trend.baseline?.stddev, deviation > 0 {
            usualRange = max(0, baseline - deviation)...(baseline + deviation)
        }

        var comparison: MetricComparison?
        if let baseline, baseline != 0 {
            let pct = (mean - baseline) / baseline * 100
            let trendUnit = trend.unit
            comparison = Self.comparison(value: mean, vsBaselinePct: pct, higherIsBetter: kind.higherIsBetter) { amountValue in
                Self.amount(amountValue, unit: trendUnit)
            }
        }

        let latest: String? = values.last.map { value in format(value) + (suffix ?? "") }

        return TrendCard(
            id: trend.metric,
            label: trend.label ?? trend.metric,
            icon: kind.icon,
            domain: kind.domain,
            style: isScore ? .line : .bars,
            points: points,
            usualRange: usualRange,
            average: format(mean),
            unit: suffix,
            latest: latest,
            comparison: comparison,
            rangeLabel: "\(days)-day average"
        )
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
}

extension HealthEndpoint.DashboardRange {
    var days: Int {
        switch self {
        case .sevenDays: 7
        case .thirtyDays: 30
        case .ninetyDays: 90
        }
    }
}
