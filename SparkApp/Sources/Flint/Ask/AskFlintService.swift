import Foundation
import SparkKit

/// What the Ask Flint screen needs from the backend. A protocol so the view
/// model can be tested without a network.
protocol AskFlintServing: Sendable {
    /// Opens a streamed answer. Throws before returning when the request is
    /// refused or the server can't be reached.
    func stream(message: String, conversationId: String?) async throws -> AsyncThrowingStream<FlintAskStreamEvent, Error>
    /// Undoes one change. Returns whether the receipt now reads as undone.
    func undo(receiptId: String) async throws -> Bool
    func conversations() async throws -> [FlintAskConversation]
    func messages(conversationId: String) async throws -> [FlintAskMessage]
    func delete(conversationId: String) async throws
}

struct AskFlintAPIService: AskFlintServing {
    let apiClient: APIClient

    func stream(message: String, conversationId: String?) async throws -> AsyncThrowingStream<FlintAskStreamEvent, Error> {
        let events = try await apiClient.events(
            for: FlintAskEndpoint.askStreaming(message: message, conversationId: conversationId)
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in events {
                        if let decoded = FlintAskStreamEvent.decode(event) {
                            continuation.yield(decoded)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func undo(receiptId: String) async throws -> Bool {
        let receipt = try await apiClient.request(CmdActionsEndpoint.undo(receiptId: receiptId))
        return receipt.undo?.available == false
    }

    /// Every conversation, newest first, up to `maximumPages` pages.
    func conversations() async throws -> [FlintAskConversation] {
        var all: [FlintAskConversation] = []
        var cursor: String?
        for _ in 0..<Self.maximumPages {
            let page = try await apiClient.request(FlintAskEndpoint.conversations(cursor: cursor))
            all.append(contentsOf: page.data)
            guard page.hasMore, let next = page.nextCursor else { break }
            cursor = next
        }
        return all
    }

    /// The whole thread, oldest first. The server pages back from the newest
    /// messages, so each older page goes in front of what is already held.
    func messages(conversationId: String) async throws -> [FlintAskMessage] {
        var all: [FlintAskMessage] = []
        var cursor: String?
        for _ in 0..<Self.maximumPages {
            let page = try await apiClient.request(
                FlintAskEndpoint.messages(conversationId: conversationId, cursor: cursor))
            all.insert(contentsOf: page.data, at: 0)
            guard page.hasMore, let next = page.nextCursor else { break }
            cursor = next
        }
        return all
    }

    /// Stops a server that never ends its pages from looping forever: 400
    /// conversations, or 600 messages of one thread.
    private static let maximumPages = 20

    func delete(conversationId: String) async throws {
        _ = try await apiClient.request(FlintAskEndpoint.deleteConversation(id: conversationId))
    }
}

/// Answers a question on the device when Spark's server can't: Private Cloud
/// Compute when it is available, the on-device model otherwise. Read-only.
protocol AskFlintLocalAnswering: Sendable {
    func answer(question: String) async -> String?
}
