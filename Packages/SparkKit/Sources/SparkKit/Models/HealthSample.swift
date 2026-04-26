import Foundation

/// Pure-Foundation mirror of the §5.6 health sample upload payload.
/// No HealthKit imports — stays in SparkKit so widgets and extensions can use it.
public struct HealthSample: Codable, Sendable {
    public let externalId: String
    public let type: String
    public let start: Date
    public let end: Date
    public let value: Double
    public let unit: String
    public let source: String
    public let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case type, value, unit, source, metadata
        case externalId = "external_id"
        case start, end
    }

    public init(
        externalId: String,
        type: String,
        start: Date,
        end: Date,
        value: Double,
        unit: String,
        source: String,
        metadata: [String: String]? = nil
    ) {
        self.externalId = externalId
        self.type = type
        self.start = start
        self.end = end
        self.value = value
        self.unit = unit
        self.source = source
        self.metadata = metadata
    }
}

public struct HealthSubmitResponse: Codable, Sendable {
    public let accepted: Int
    public let rejected: Int

    public init(accepted: Int, rejected: Int) {
        self.accepted = accepted
        self.rejected = rejected
    }
}

/// Batch payload for POST /health/samples.
public struct HealthSampleBatch: Codable, Sendable {
    public let samples: [HealthSample]

    public init(samples: [HealthSample]) {
        self.samples = samples
    }
}
