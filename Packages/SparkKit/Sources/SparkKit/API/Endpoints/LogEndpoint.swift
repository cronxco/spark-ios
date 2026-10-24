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

public extension LogEndpoint {
    /// A line that is not wine, beer, TV, cinema or a board game, logged as a
    /// `reflection`: a document object plus a "Logged a Reflection" event.
    struct ReflectionRequest: Encodable, Sendable {
        public let idempotencyKey: String
        public let body: String
        public let occurredAt: Date

        public init(idempotencyKey: String, body: String, occurredAt: Date) {
            self.idempotencyKey = idempotencyKey
            self.body = body
            self.occurredAt = occurredAt
        }

        enum CodingKeys: String, CodingKey {
            case kind, body
            case idempotencyKey = "idempotency_key"
            case occurredAt = "occurred_at"
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("reflection", forKey: .kind)
            try container.encode(body, forKey: .body)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
            try container.encode(occurredAt, forKey: .occurredAt)
        }
    }

    /// The reflection answer isn't read; any 2xx means it's saved (201 new,
    /// 200 replay of the same key).
    struct ReflectionResponse: Decodable, Sendable {}

    static func reflection(_ request: ReflectionRequest) -> Endpoint<ReflectionResponse> {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return Endpoint(
            method: .post,
            path: "/log",
            body: try? encoder.encode(request),
            contentType: "application/json"
        )
    }
}
