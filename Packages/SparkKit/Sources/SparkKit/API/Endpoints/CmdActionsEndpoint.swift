import Foundation

/// The action registry's native face: list, run, and undo by receipt.
public enum CmdActionsEndpoint {
    public struct Action: Decodable, Equatable, Sendable {
        public struct Field: Decodable, Equatable, Sendable {
            public let required: Bool?
        }

        public let id: String
        public let title: String
        /// `navigation`, `safe` or `data`.
        public let kind: String
        /// `none`, `undo` or `confirm`.
        public let confirm: String
        public let target: [String: Field]

        /// Runs with nothing but its name: no required field to fill in.
        public var runsWithoutInput: Bool {
            target.values.allSatisfy { $0.required == false }
        }
    }

    public struct ListResponse: Decodable, Equatable, Sendable {
        public let data: [Action]
    }

    public struct Receipt: Decodable, Equatable, Sendable {
        public struct Undo: Decodable, Equatable, Sendable {
            public let available: Bool
        }

        public let receiptId: String
        /// `accepted`, `running`, `succeeded` or `failed`.
        public let status: String
        public let message: String?
        public let undo: Undo?

        enum CodingKeys: String, CodingKey {
            case status, message, undo
            case receiptId = "receipt_id"
        }
    }

    public struct RunRequest: Encodable, Sendable {
        public let confirmed: Bool
    }

    public static func list(query: String) -> Endpoint<ListResponse> {
        Endpoint(method: .get, path: "/actions", query: [URLQueryItem(name: "q", value: query)])
    }

    /// `idempotencyKey` replays the first receipt on a retry.
    public static func run(id: String, confirmed: Bool, idempotencyKey: String) -> Endpoint<Receipt> {
        Endpoint(
            method: .post,
            path: "/actions/\(id)/run",
            body: try? JSONEncoder().encode(RunRequest(confirmed: confirmed)),
            contentType: "application/json",
            headers: ["Idempotency-Key": idempotencyKey]
        )
    }

    public static func undo(receiptId: String) -> Endpoint<Receipt> {
        Endpoint(method: .post, path: "/actions/receipts/\(receiptId)/undo")
    }
}
