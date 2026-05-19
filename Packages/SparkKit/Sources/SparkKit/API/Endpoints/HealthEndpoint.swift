import Foundation

public enum HealthEndpoint {
    public enum DashboardRange: String, Sendable, CaseIterable {
        case sevenDays = "7d"
        case thirtyDays = "30d"
        case ninetyDays = "90d"

        public var label: String {
            switch self {
            case .sevenDays: "7D"
            case .thirtyDays: "30D"
            case .ninetyDays: "90D"
            }
        }
    }

    /// GET /health/dashboard?date=YYYY-MM-DD&range=7d
    public static func dashboard(date: String = "today", range: DashboardRange = .sevenDays) -> Endpoint<HealthDashboard> {
        Endpoint(
            method: .get,
            path: "/health/dashboard",
            query: [
                URLQueryItem(name: "date", value: date),
                URLQueryItem(name: "range", value: range.rawValue),
            ]
        )
    }

    /// POST /health/samples
    public static func submit(samples: [HealthSample]) -> Endpoint<HealthSubmitResponse> {
        let body = try? JSONEncoder().encode(HealthSampleBatch(samples: samples))
        return Endpoint(method: .post, path: "/health/samples", body: body, contentType: "application/json")
    }
}
