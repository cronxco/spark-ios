import Foundation

public enum LogEndpoint {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// POST /log — write wine, beer, TV, cinema or board game events from a
    /// structured draft. Answers 201 for new events, 200 for a replay of the
    /// same idempotency key or for a clarification, and 422 for input it
    /// cannot log (such as a series TheTVDB does not know).
    ///
    /// With `dryRun` set, answers what would match and writes nothing.
    public static func submit(_ request: LogRequest) -> Endpoint<LogResponse> {
        Endpoint(
            method: .post,
            path: "/log",
            body: try? encoder.encode(request),
            contentType: "application/json"
        )
    }
}
