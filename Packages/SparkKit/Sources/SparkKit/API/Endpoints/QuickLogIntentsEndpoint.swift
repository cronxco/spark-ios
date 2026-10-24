import Foundation

/// Quick log intents, contract v1: classify a line, then commit the intent
/// the user settled on. Only `flint_note` is written by the server; `log`,
/// `command` and `search` answer `client_action`.
public enum QuickLogIntentsEndpoint {
    public struct Hint: Codable, Equatable, Sendable {
        public let intent: String
        public let confidence: Double

        public init(intent: String, confidence: Double) {
            self.intent = intent
            self.confidence = confidence
        }
    }

    public struct ClassifyRequest: Encodable, Sendable {
        public let text: String
        public let hint: Hint?

        public init(text: String, hint: Hint?) {
            self.text = text
            self.hint = hint
        }
    }

    public struct ClassifyResponse: Decodable, Equatable, Sendable {
        /// `log`, `flint_note`, `command`, `search` or `unsure`.
        public let intent: String
        public let confidence: Double
        public let needsChoice: Bool
        public let text: String

        enum CodingKeys: String, CodingKey {
            case intent, confidence, text
            case needsChoice = "needs_choice"
        }
    }

    public struct CommitRequest: Encodable, Sendable {
        public let idempotencyKey: String
        public let text: String
        public let intent: String
        public let suggestedIntent: String?
        public let confidence: Double?
        public let occurredAt: Date

        public init(
            idempotencyKey: String, text: String, intent: String,
            suggestedIntent: String?, confidence: Double?, occurredAt: Date
        ) {
            self.idempotencyKey = idempotencyKey
            self.text = text
            self.intent = intent
            self.suggestedIntent = suggestedIntent
            self.confidence = confidence
            self.occurredAt = occurredAt
        }

        enum CodingKeys: String, CodingKey {
            case text, intent, confidence
            case idempotencyKey = "idempotency_key"
            case suggestedIntent = "suggested_intent"
            case occurredAt = "occurred_at"
        }
    }

    public struct CommitResponse: Decodable, Equatable, Sendable {
        /// `saved` for a note for Flint, `client_action` otherwise.
        public let status: String
        public let intent: String
    }

    public static func classify(_ request: ClassifyRequest) -> Endpoint<ClassifyResponse> {
        Endpoint(
            method: .post,
            path: "/log/intents/classify",
            body: try? JSONEncoder().encode(request),
            contentType: "application/json"
        )
    }

    public static func commit(_ request: CommitRequest) -> Endpoint<CommitResponse> {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return Endpoint(
            method: .post,
            path: "/log/intents",
            body: try? encoder.encode(request),
            contentType: "application/json"
        )
    }
}
