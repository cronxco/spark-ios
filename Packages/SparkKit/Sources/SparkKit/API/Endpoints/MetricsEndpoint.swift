import Foundation

public enum MetricsEndpoint {
    public enum Range: String, Sendable, CaseIterable {
        case sevenDays = "7d"
        case thirtyDays = "30d"
        case ninetyDays = "90d"
        case year = "1y"

        public var label: String {
            switch self {
            case .sevenDays: "7D"
            case .thirtyDays: "30D"
            case .ninetyDays: "90D"
            case .year: "1Y"
            }
        }
    }

    /// GET /metrics/{identifier}?range=…
    public static func detail(identifier: String, range: Range = .thirtyDays) -> Endpoint<MetricDetail> {
        Endpoint(
            method: .get,
            path: "/metrics/\(identifier)",
            query: [URLQueryItem(name: "range", value: range.rawValue)]
        )
    }
}
