import Foundation

public enum CheckInsEndpoint {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// POST /check-ins — submit or update a morning/afternoon check-in.
    public static func submit(_ request: CheckInRequest) -> Endpoint<CheckInEvent> {
        Endpoint(
            method: .post,
            path: "/check-ins",
            body: try? encoder.encode(request),
            contentType: "application/json"
        )
    }

    /// GET /check-ins?date=YYYY-MM-DD — completion status for both periods on a date.
    public static func today(date: String) -> Endpoint<CheckInDayResponse> {
        Endpoint(
            method: .get,
            path: "/check-ins",
            query: [URLQueryItem(name: "date", value: date)]
        )
    }

    /// GET /check-ins/history?from=YYYY-MM-DD&to=YYYY-MM-DD — day-by-day history (max 90 days).
    public static func history(from: String, to: String) -> Endpoint<CheckInHistoryResponse> {
        Endpoint(
            method: .get,
            path: "/check-ins/history",
            query: [
                URLQueryItem(name: "from", value: from),
                URLQueryItem(name: "to", value: to),
            ]
        )
    }
}
