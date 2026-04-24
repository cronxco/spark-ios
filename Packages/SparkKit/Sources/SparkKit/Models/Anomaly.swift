import Foundation

/// Anomaly surfaced in the day summary payload. Field shape tracks
/// `DaySummaryService::buildAnomalies()` on the backend.
public struct Anomaly: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let metric: String?
    public let severity: String?
    public let description: String?
    public let detectedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, metric, severity, description
        case detectedAt = "detected_at"
    }

    public init(
        id: String,
        metric: String? = nil,
        severity: String? = nil,
        description: String? = nil,
        detectedAt: Date? = nil
    ) {
        self.id = id
        self.metric = metric
        self.severity = severity
        self.description = description
        self.detectedAt = detectedAt
    }
}
