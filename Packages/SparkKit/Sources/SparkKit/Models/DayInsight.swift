import Foundation

/// A plain-language comparison from the day summary's `insights[]`: a week
/// against its four-week trend, a day against what is typical, or a week on
/// one side of usual. Field shape tracks `DaySummaryService::buildInsights()`.
public struct DayInsight: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let metric: String?
    public let displayName: String?
    /// `insight_period`, `insight_typical` or `insight_shift`.
    public let kind: String?
    /// `up` or `down`.
    public let direction: String?
    public let valence: AnomalyValence
    public let currentValue: Double?
    public let baselineValue: Double?
    /// Server-formatted, through the metric's own formatter.
    public let currentDisplay: String?
    public let deltaDisplay: String?
    /// `4w trend` or `usual`.
    public let comparison: String?
    /// Set when the server found that the day type matters, "a Thursday" or
    /// "a weekend day". Absent when it did not, so it is never invented here.
    public let dayLabel: String?
    public let startDate: String?
    public let endDate: String?

    enum CodingKeys: String, CodingKey {
        case id, metric, kind, direction, valence, comparison
        case displayName = "display_name"
        case currentValue = "current_value"
        case baselineValue = "baseline_value"
        case currentDisplay = "current_display"
        case deltaDisplay = "delta_display"
        case dayLabel = "day_label"
        case startDate = "start_date"
        case endDate = "end_date"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        metric = try c.decodeIfPresent(String.self, forKey: .metric)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        kind = try c.decodeIfPresent(String.self, forKey: .kind)
        direction = try c.decodeIfPresent(String.self, forKey: .direction)
        let rawValence = try c.decodeIfPresent(String.self, forKey: .valence)
        valence = rawValence.flatMap(AnomalyValence.init(rawValue:)) ?? .neutral
        currentValue = try c.decodeIfPresent(Double.self, forKey: .currentValue)
        baselineValue = try c.decodeIfPresent(Double.self, forKey: .baselineValue)
        currentDisplay = try c.decodeIfPresent(String.self, forKey: .currentDisplay)
        deltaDisplay = try c.decodeIfPresent(String.self, forKey: .deltaDisplay)
        comparison = try c.decodeIfPresent(String.self, forKey: .comparison)
        dayLabel = try c.decodeIfPresent(String.self, forKey: .dayLabel)
        startDate = try c.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try c.decodeIfPresent(String.self, forKey: .endDate)
        let decodedId = try c.decodeIfPresent(String.self, forKey: .id)
        id = decodedId ?? "\(metric ?? "insight")|\(kind ?? "")|\(endDate ?? "")"
    }

    public init(
        id: String,
        metric: String? = nil,
        displayName: String? = nil,
        kind: String? = nil,
        direction: String? = nil,
        valence: AnomalyValence = .neutral,
        currentValue: Double? = nil,
        baselineValue: Double? = nil,
        currentDisplay: String? = nil,
        deltaDisplay: String? = nil,
        comparison: String? = nil,
        dayLabel: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) {
        self.id = id
        self.metric = metric
        self.displayName = displayName
        self.kind = kind
        self.direction = direction
        self.valence = valence
        self.currentValue = currentValue
        self.baselineValue = baselineValue
        self.currentDisplay = currentDisplay
        self.deltaDisplay = deltaDisplay
        self.comparison = comparison
        self.dayLabel = dayLabel
        self.startDate = startDate
        self.endDate = endDate
    }

    public var isDown: Bool { direction == "down" }

    /// The sentence under the metric's name. A week is compared as a daily
    /// average, so the figure is worded "a day".
    public var sentence: String {
        let current = currentDisplay ?? currentValue.map(Self.plain) ?? "—"
        let delta = deltaDisplay.map { "\($0) \(isDown ? "less" : "more")" } ?? (isDown ? "lower" : "higher")

        switch kind {
        case "insight_period":
            return "\(current) a day, \(delta) than the last 4 weeks"
        case "insight_shift":
            return "\(current) a day this week, \(delta) than usual"
        default:
            let day = dayLabel.map { " for \($0)" } ?? ""
            return "\(current), \(delta) than usual\(day)"
        }
    }

    private static func plain(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return value == value.rounded()
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
