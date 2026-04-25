import Foundation

/// Returned by `/api/v1/mobile/metrics/{metric}?range=…`. Carries the trend
/// series, baseline band, and any anomalies the screen needs to render
/// without follow-up requests.
public struct MetricDetail: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let domain: String
    public let unit: String?
    public let today: Double?
    public let yesterday: Double?
    public let average30d: Double?
    public let baseline: Baseline?
    public let series: [Point]
    public let anomalies: [AnomalyPoint]
    public let compares: [Compare]?

    public struct Baseline: Codable, Sendable, Hashable {
        public let low: Double
        public let high: Double
        public init(low: Double, high: Double) {
            self.low = low
            self.high = high
        }
    }

    public struct Point: Codable, Sendable, Hashable, Identifiable {
        public let date: Date
        public let value: Double
        public var id: Date { date }
        public init(date: Date, value: Double) {
            self.date = date
            self.value = value
        }
    }

    public struct AnomalyPoint: Codable, Sendable, Hashable, Identifiable {
        public let id: String
        public let date: Date
        public let severity: String
        public let note: String?
        public let value: Double?
        public init(id: String, date: Date, severity: String, note: String? = nil, value: Double? = nil) {
            self.id = id
            self.date = date
            self.severity = severity
            self.note = note
            self.value = value
        }
    }

    public struct Compare: Codable, Sendable, Hashable, Identifiable {
        public let label: String
        public let value: Double
        public let delta: Double?
        public var id: String { label }
        public init(label: String, value: Double, delta: Double? = nil) {
            self.label = label
            self.value = value
            self.delta = delta
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, domain, unit, today, yesterday, baseline, series, anomalies, compares
        case average30d = "average_30d"
    }

    public init(
        id: String,
        title: String,
        domain: String,
        unit: String? = nil,
        today: Double? = nil,
        yesterday: Double? = nil,
        average30d: Double? = nil,
        baseline: Baseline? = nil,
        series: [Point] = [],
        anomalies: [AnomalyPoint] = [],
        compares: [Compare]? = nil
    ) {
        self.id = id
        self.title = title
        self.domain = domain
        self.unit = unit
        self.today = today
        self.yesterday = yesterday
        self.average30d = average30d
        self.baseline = baseline
        self.series = series
        self.anomalies = anomalies
        self.compares = compares
    }
}

public extension MetricDetail {
    /// Match an anomaly to its y-value from the series so the chart can pin
    /// it accurately even when the backend omits per-anomaly values.
    func valueForAnomaly(_ anomaly: AnomalyPoint) -> Double? {
        if let value = anomaly.value { return value }
        return series.first(where: { Calendar.current.isDate($0.date, inSameDayAs: anomaly.date) })?.value
    }
}
