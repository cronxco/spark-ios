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
        /// Navigation actions only.
        public let destination: Destination?

        public struct Destination: Decodable, Equatable, Sendable {
            /// The app screen to open, such as `flint` or `explore.money`.
            public let native: String?
        }

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

    /// What a typed line such as "sync monzo" resolved to.
    public struct Resolution: Decodable, Equatable, Sendable {
        public struct Candidate: Decodable, Equatable, Sendable {
            public let label: String
            public let target: [String: String]
        }

        /// `matched`, `ambiguous`, `incomplete` or `none`.
        public let status: String
        public let message: String?
        public let action: Action?
        public let target: [String: String]?
        public let label: String?
        public let candidates: [Candidate]?
    }

    public struct ResolveResponse: Decodable, Equatable, Sendable {
        public let data: Resolution
    }

    public struct RunRequest: Encodable, Sendable {
        public let confirmed: Bool
        public let target: [String: String]?
    }

    public static func list(query: String) -> Endpoint<ListResponse> {
        Endpoint(method: .get, path: "/actions", query: [URLQueryItem(name: "q", value: query)])
    }

    public static func resolve(query: String) -> Endpoint<ResolveResponse> {
        Endpoint(method: .get, path: "/actions/resolve", query: [URLQueryItem(name: "q", value: query)])
    }

    /// `idempotencyKey` replays the first receipt on a retry. `target` names
    /// the event or integration a targeted action acts on.
    public static func run(
        id: String, target: [String: String] = [:], confirmed: Bool, idempotencyKey: String
    ) -> Endpoint<Receipt> {
        Endpoint(
            method: .post,
            path: "/actions/\(id)/run",
            body: try? JSONEncoder().encode(RunRequest(confirmed: confirmed, target: target.isEmpty ? nil : target)),
            contentType: "application/json",
            headers: ["Idempotency-Key": idempotencyKey]
        )
    }

    public static func undo(receiptId: String) -> Endpoint<Receipt> {
        Endpoint(method: .post, path: "/actions/receipts/\(receiptId)/undo")
    }
}
