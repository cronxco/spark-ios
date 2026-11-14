import Foundation

/// Ask Flint: ask a question (whole answer or streamed), and read or delete
/// the conversations it leaves. A change Flint made is undone with
/// `CmdActionsEndpoint.undo(receiptId:)`.
public enum FlintAskEndpoint {
    public static let maximumMessageLength = 4000

    struct AskRequest: Encodable {
        let message: String
        let conversationId: String?
        let stream: Bool
        var readOnly: Bool?

        enum CodingKeys: String, CodingKey {
            case message, stream
            case conversationId = "conversation_id"
            case readOnly = "read_only"
        }
    }

    /// POST /flint/ask — waits for the whole answer. For Siri and other
    /// callers that can't consume a stream. `readOnly` asks the server to
    /// withhold Flint's write tools for this turn, so nothing can change
    /// where no Undo can be shown.
    public static func ask(
        message: String, conversationId: String? = nil, readOnly: Bool = false
    ) -> Endpoint<FlintAskAnswer> {
        Endpoint(
            method: .post,
            path: "/flint/ask",
            body: try? JSONEncoder().encode(
                AskRequest(
                    message: message, conversationId: conversationId, stream: false,
                    readOnly: readOnly ? true : nil)),
            contentType: "application/json"
        )
    }

    /// POST /flint/ask with `stream: true` — open with `APIClient.events(for:)`
    /// and decode each frame with `FlintAskStreamEvent.decode`.
    public static func askStreaming(message: String, conversationId: String? = nil) -> Endpoint<EmptyResponse> {
        Endpoint(
            method: .post,
            path: "/flint/ask",
            body: try? JSONEncoder().encode(AskRequest(message: message, conversationId: conversationId, stream: true)),
            contentType: "application/json"
        )
    }

    /// GET /flint/ask/conversations — newest first.
    public static func conversations(cursor: String? = nil, limit: Int = 20) -> Endpoint<FlintAskConversationsPage> {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        return Endpoint(method: .get, path: "/flint/ask/conversations", query: query)
    }

    /// GET /flint/ask/conversations/{id} — the newest messages, oldest first.
    public static func messages(conversationId: String, cursor: String? = nil, limit: Int = 30) -> Endpoint<FlintAskMessagesPage> {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        return Endpoint(method: .get, path: "/flint/ask/conversations/\(conversationId)", query: query)
    }

    /// DELETE /flint/ask/conversations/{id} — the thread goes; changes it made stay.
    public static func deleteConversation(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .delete, path: "/flint/ask/conversations/\(id)")
    }
}
