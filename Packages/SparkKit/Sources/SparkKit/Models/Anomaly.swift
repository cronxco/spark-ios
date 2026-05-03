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

    enum CodingKeys: String, CodingKey {
        case metric, type, direction, deviation
        case displayName = "display_name"
        case currentValue = "current_value"
        case baselineValue = "baseline_value"
        case streakDays = "streak_days"
        case detectedAt = "detected_at"
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
        detectedAt: Date? = nil
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
    }
}
