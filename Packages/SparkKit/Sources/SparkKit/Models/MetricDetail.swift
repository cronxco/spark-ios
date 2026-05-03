import Foundation

/// Returned by `/api/v1/mobile/metrics/{metric}?range=…`. Carries the trend
/// series, baseline band, and any anomalies the screen needs to render
/// without follow-up requests.
public struct MetricDetail: Sendable, Hashable, Identifiable {
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

    public struct Baseline: Sendable, Hashable {
        public let low: Double
        public let high: Double
        public init(low: Double, high: Double) {
            self.low = low
            self.high = high
        }
    }

    public struct Point: Sendable, Hashable, Identifiable {
        public let date: Date
        public let value: Double
        public var id: Date { date }
        public init(date: Date, value: Double) {
            self.date = date
            self.value = value
        }
    }

    public struct AnomalyPoint: Sendable, Hashable, Identifiable {
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

    public struct Compare: Sendable, Hashable, Identifiable {
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

// MARK: - Codable (maps the actual API response shape)

extension MetricDetail: Codable {
    private struct APIResponse: Codable {
        let metric: String
        let service: String
        let action: String
        let unit: String?
        let dailyValues: [DailyValue]
        let summary: Summary?
        let baseline: APIBaseline?

        struct DailyValue: Codable {
            let date: String
            let value: Double
            let isAnomaly: Bool

            enum CodingKeys: String, CodingKey {
                case date, value
                case isAnomaly = "is_anomaly"
            }
        }

        struct Summary: Codable {
            let mean: Double?
        }

        struct APIBaseline: Codable {
            let normalLower: Double?
            let normalUpper: Double?

            enum CodingKeys: String, CodingKey {
                case normalLower = "normal_lower"
                case normalUpper = "normal_upper"
            }
        }

        enum CodingKeys: String, CodingKey {
            case metric, service, action, unit, summary, baseline
            case dailyValues = "daily_values"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    public init(from decoder: Decoder) throws {
        let api = try APIResponse(from: decoder)

        id = api.metric
        domain = api.service
        unit = api.unit
        average30d = api.summary?.mean
        compares = nil

        // Derive a human-readable title from the action field.
        // e.g. "had_sleep_score" → "Sleep Score", "had_heart_rate" → "Heart Rate"
        let stripped = api.action.hasPrefix("had_") ? String(api.action.dropFirst(4)) : api.action
        title = stripped.split(separator: "_").map { $0.capitalized }.joined(separator: " ")

        if let lo = api.baseline?.normalLower, let hi = api.baseline?.normalUpper {
            baseline = Baseline(low: lo, high: hi)
        } else {
            baseline = nil
        }

        let fmt = Self.dateFormatter
        series = api.dailyValues.compactMap { dv in
            guard let date = fmt.date(from: dv.date) else { return nil }
            return Point(date: date, value: dv.value)
        }

        today = series.last?.value
        yesterday = series.count >= 2 ? series[series.count - 2].value : nil

        anomalies = api.dailyValues.compactMap { dv -> AnomalyPoint? in
            guard dv.isAnomaly, let date = fmt.date(from: dv.date) else { return nil }
            return AnomalyPoint(id: dv.date, date: date, severity: "high", value: dv.value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        // Encoding is not needed for read-only API responses; satisfy Codable
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
    }

    private enum CodingKeys: String, CodingKey {
        case id
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
