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

// MARK: - Daily readings

public extension HealthSample {
    /// Largest batch `POST /health/samples` accepts.
    static let maxBatchSize = 500

    /// One metric's reading for one local day: the day's cumulative total for
    /// a summed metric such as steps, or its average for a discrete one such
    /// as heart rate. The server keeps one reading per metric per day and
    /// replaces it with any reading taken later, so the client re-sends the
    /// day as it grows rather than individual samples it would have to add up.
    ///
    /// - `metadata.date` names the local day, because `start` is encoded in
    ///   UTC and local midnight falls on the previous UTC date east of UTC.
    /// - `metadata.as_of` is when the reading was taken, which decides whether
    ///   it replaces the one on record.
    static func dailyReading(
        type: String,
        day: Date,
        value: Double,
        unit: String,
        source: String,
        asOf: Date,
        calendar: Calendar = .current
    ) -> HealthSample {
        let start = calendar.startOfDay(for: day)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let date = localDateString(start, calendar: calendar)

        return HealthSample(
            externalId: "\(type):\(date)",
            type: type,
            start: start,
            end: min(asOf, nextDay),
            value: value,
            unit: unit,
            source: source,
            metadata: [
                "date": date,
                "as_of": asOf.formatted(.iso8601),
            ]
        )
    }

    private static func localDateString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

public extension HealthSampleBatch {
    /// Splits samples into batches the server accepts, in order.
    static func batches(of samples: [HealthSample], maxSize: Int = HealthSample.maxBatchSize) -> [HealthSampleBatch] {
        let size = max(1, maxSize)
        return stride(from: 0, to: samples.count, by: size).map { offset in
            HealthSampleBatch(samples: Array(samples[offset ..< min(offset + size, samples.count)]))
        }
    }
}
