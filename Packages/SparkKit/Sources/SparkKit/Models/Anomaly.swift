import Foundation

/// Anomaly surfaced in the day summary payload. Field shape tracks
/// `DaySummaryService::buildAnomalies()` on the backend.
public struct Anomaly: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let metric: String?
    public let displayName: String?
    public let type: String?
    public let direction: String?
    public let currentValue: Double?
    public let baselineValue: Double?
    public let deviation: Double?
    public let streakDays: Int?
    public let detectedAt: Date?
    /// Which part of life this metric belongs to — health, money, media,
    /// knowledge, online. Without it every anomaly looked like a health one.
    public let domain: String?
    public let service: String?
    public let unit: String?
    /// Whether a move in `direction` is good, bad, or neither. Direction alone
    /// cannot say: a balance rising is good news, a cardiovascular age rising
    /// is not.
    public let valence: AnomalyValence
    /// True when the metric is a banded score rather than a continuous
    /// quantity, so a percentage change against a fractional baseline would be
    /// meaningless.
    public let isOrdinal: Bool
    /// Server-formatted values, already through the plugin's own formatter —
    /// "£2,082.23", "44 years", "Adequate".
    public let currentDisplay: String?
    public let baselineDisplay: String?
    /// Set when the anomaly has been dismissed rather than merely read.
    public let acknowledgedAt: Date?

    enum CodingKeys: String, CodingKey {
        case metric, type, direction, deviation, domain, service, unit, valence
        case displayName = "display_name"
        case currentValue = "current_value"
        case baselineValue = "baseline_value"
        case streakDays = "streak_days"
        case detectedAt = "detected_at"
        case isOrdinal = "is_ordinal"
        case currentDisplay = "current_display"
        case baselineDisplay = "baseline_display"
        case acknowledgedAt = "acknowledged_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        metric = try c.decodeIfPresent(String.self, forKey: .metric)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        direction = try c.decodeIfPresent(String.self, forKey: .direction)
        currentValue = try c.decodeIfPresent(Double.self, forKey: .currentValue)
        baselineValue = try c.decodeIfPresent(Double.self, forKey: .baselineValue)
        deviation = try c.decodeIfPresent(Double.self, forKey: .deviation)
        streakDays = try c.decodeIfPresent(Int.self, forKey: .streakDays)
        detectedAt = try c.decodeIfPresent(Date.self, forKey: .detectedAt)
        domain = try c.decodeIfPresent(String.self, forKey: .domain)
        service = try c.decodeIfPresent(String.self, forKey: .service)
        unit = try c.decodeIfPresent(String.self, forKey: .unit)
        valence = try c.decodeIfPresent(AnomalyValence.self, forKey: .valence) ?? .neutral
        isOrdinal = try c.decodeIfPresent(Bool.self, forKey: .isOrdinal) ?? false
        currentDisplay = try c.decodeIfPresent(String.self, forKey: .currentDisplay)
        baselineDisplay = try c.decodeIfPresent(String.self, forKey: .baselineDisplay)
        acknowledgedAt = try c.decodeIfPresent(Date.self, forKey: .acknowledgedAt)
        let detectedStr = detectedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "unknown"
        id = "\(metric ?? "anomaly")|\(detectedStr)"
    }

    public init(
        id: String,
        metric: String? = nil,
        displayName: String? = nil,
        type: String? = nil,
        direction: String? = nil,
        currentValue: Double? = nil,
        baselineValue: Double? = nil,
        deviation: Double? = nil,
        streakDays: Int? = nil,
        detectedAt: Date? = nil,
        domain: String? = nil,
        service: String? = nil,
        unit: String? = nil,
        valence: AnomalyValence = .neutral,
        isOrdinal: Bool = false,
        currentDisplay: String? = nil,
        baselineDisplay: String? = nil,
        acknowledgedAt: Date? = nil
    ) {
        self.id = id
        self.metric = metric
        self.displayName = displayName
        self.type = type
        self.direction = direction
        self.currentValue = currentValue
        self.baselineValue = baselineValue
        self.deviation = deviation
        self.streakDays = streakDays
        self.detectedAt = detectedAt
        self.domain = domain
        self.service = service
        self.unit = unit
        self.valence = valence
        self.isOrdinal = isOrdinal
        self.currentDisplay = currentDisplay
        self.baselineDisplay = baselineDisplay
        self.acknowledgedAt = acknowledgedAt
    }

    /// The value to show for "now", preferring the server's formatting.
    public var currentText: String? {
        currentDisplay ?? currentValue.map { Self.plain($0) }
    }

    /// The value to show for the baseline, preferring the server's formatting.
    public var baselineText: String? {
        baselineDisplay ?? baselineValue.map { Self.plain($0) }
    }

    /// Percentage change against the baseline — meaningless for a banded score,
    /// so absent for one.
    public var percentChange: Double? {
        guard !isOrdinal, let current = currentValue, let baseline = baselineValue, baseline != 0 else {
            return nil
        }
        return (current - baseline) / abs(baseline) * 100
    }

    private static func plain(_ value: Double) -> String {
        // Int(value) traps on non-finite or out-of-range doubles, and these
        // come straight off the wire.
        guard value.isFinite else { return "—" }
        return value == value.rounded()
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

/// Whether a movement is welcome. Distinct from direction, which only says
/// which way the number went.
public enum AnomalyValence: String, Codable, Sendable, Hashable {
    case good
    case bad
    case neutral
}
