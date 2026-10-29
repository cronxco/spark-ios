import Foundation

/// Which card layout an event gets, parsed from `{service}.{action}`.
///
/// The event counterpart of `BlockKind`: one registry, one generic fallback,
/// so adding a type means adding a case here and its entry in the web's
/// `App\Support\EventCardKind`. Only kinds that Flint quotes in a briefing
/// have their own case so far; everything else is `.generic` and shows the
/// server's formatted value under the action's display name.
public enum EventKind: Hashable, Sendable {
    case sleepScore
    case readinessScore
    case activityScore
    case sleepDuration
    case steps
    case exerciseTime
    case generic(String)

    public init(_ key: String) {
        switch key {
        case "oura.had_sleep_score": self = .sleepScore
        case "oura.had_readiness_score": self = .readinessScore
        case "oura.had_activity_score": self = .activityScore
        case "oura.slept_for": self = .sleepDuration
        case "apple_health.had_step_count": self = .steps
        case "apple_health.had_apple_exercise_time": self = .exerciseTime
        default: self = .generic(key)
        }
    }

    public init(_ event: Event) {
        self.init("\(event.service).\(event.action)")
    }

    /// How the hero value reads (design language §9).
    public enum ValueFormat: Sendable {
        /// A bare rounded number: `88`.
        case score
        /// `7h 55m`, `42m` or `1m 05s`, from the event's unit.
        case duration
        /// Grouping separators: `8,015`.
        case count
        /// The server's own `display_value`, as the plugin formats it.
        case display
    }

    public var valueFormat: ValueFormat {
        switch self {
        case .sleepScore, .readinessScore, .activityScore: .score
        case .sleepDuration, .exerciseTime: .duration
        case .steps: .count
        case .generic: .display
        }
    }

    /// The top of the scale, for kinds drawn as a ring. `nil` means the kind
    /// has no known maximum and must never be drawn as one.
    public var ringMaximum: Double? {
        switch self {
        case .sleepScore, .readinessScore, .activityScore: 100
        default: nil
        }
    }

    /// Whether the compact card draws the value as a bar against the
    /// reader's 30d average (design language §8, "against the mean").
    public var drawsAgainstMean: Bool {
        switch self {
        case .sleepDuration, .steps, .exerciseTime: true
        default: false
        }
    }

    /// The short eyebrow label. `nil` for `.generic`, which uses the
    /// backend's `display_name` instead of guessing one.
    public var shortLabel: String? {
        switch self {
        case .sleepScore: "Sleep score"
        case .readinessScore: "Readiness"
        case .activityScore: "Activity score"
        case .sleepDuration: "Sleep"
        case .steps: "Steps"
        case .exerciseTime: "Exercise"
        case .generic: nil
        }
    }

    /// The hero text for a value. A missing value is "—", never zero.
    public func heroValue(_ value: Double?, unit: String?, displayValue: String?) -> String {
        guard let value else { return "—" }

        switch valueFormat {
        case .score:
            return String(Int(value.rounded()))
        case .count:
            return value.formatted(.number.precision(.fractionLength(0)))
        case .duration:
            return Self.duration(seconds: Self.seconds(value, unit: unit))
        case .display:
            let display = displayValue?.sparkPlainTextFromHTMLFragment
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !display.isEmpty { return display }
            return value.formatted(.number.precision(.fractionLength(0 ... 1)))
        }
    }

    /// "7h 55m", "42m" or "1m 05s" — the one duration style (design language §9).
    public static func duration(seconds: Double) -> String {
        let total = Int(max(0, seconds).rounded())

        if total < 3600 {
            let minutes = total / 60
            let remainder = total % 60
            if minutes == 0 { return "\(remainder)s" }
            if remainder == 0 || minutes >= 10 { return "\(minutes)m" }
            return String(format: "%dm %02ds", minutes, remainder)
        }

        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    private static func seconds(_ value: Double, unit: String?) -> Double {
        switch (unit ?? "").lowercased() {
        case "ms", "millisecond", "milliseconds": value / 1000
        case "m", "min", "mins", "minute", "minutes": value * 60
        case "h", "hr", "hrs", "hour", "hours": value * 3600
        default: value
        }
    }
}
