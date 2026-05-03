import Foundation

public enum CheckInsEndpoint {
    /// GET /check-ins?date=YYYY-MM-DD
    public static func list(date: String) -> Endpoint<[CheckIn]> {
        Endpoint(method: .get, path: "/check-ins", query: [URLQueryItem(name: "date", value: date)])
    }

    /// POST /check-ins
    public static func create(_ checkIn: CheckIn) -> Endpoint<EmptyResponse> {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try? encoder.encode(checkIn)
        return Endpoint(method: .post, path: "/check-ins", body: body, contentType: "application/json")
    }
}
