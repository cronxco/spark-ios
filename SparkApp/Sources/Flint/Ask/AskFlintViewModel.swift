import Foundation
import Observation
import SparkKit

@MainActor
@Observable
final class AskFlintViewModel {
    /// One bubble in the thread.
    struct Turn: Identifiable, Equatable {
        enum Source: Equatable {
            /// Spark's server-side agent.
            case spark
            /// Apple's model on this device or Private Cloud Compute, used
            /// when the server could not answer. Read-only.
            case local
        }

        let id: String
        let role: FlintAskMessage.Role
        var text: String
        var references: [FlintAskReference] = []
        var changes: [FlintAskChange] = []
        var isStreaming = false
        var failed = false
        var source: Source = .spark
    }

    enum HistoryState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    private(set) var turns: [Turn] = []
    private(set) var conversationId: String?
    private(set) var isResponding = false
    /// What Flint is doing right now, e.g. "Searching Spark".
    private(set) var activity: String?
    private(set) var errorMessage: String?
    private(set) var undoingReceiptIDs: Set<String> = []
    private(set) var conversations: [FlintAskConversation] = []
    private(set) var historyState: HistoryState = .idle
    private(set) var isLoadingConversation = false
    var draft = ""

    private let service: any AskFlintServing
    private let localAnswerer: (any AskFlintLocalAnswering)?
    private var responseTask: Task<Void, Never>?
    /// The history load whose result may still be shown. A newer selection
    /// or a new conversation replaces it, so a slow earlier load is dropped.
    private var historyLoadID: UUID?

    init(service: any AskFlintServing, localAnswerer: (any AskFlintLocalAnswering)? = nil) {
        self.service = service
        self.localAnswerer = localAnswerer
    }

    var canSend: Bool {
        !isResponding && !isLoadingConversation && !trimmedDraft.isEmpty
            && trimmedDraft.count <= FlintAskEndpoint.maximumMessageLength
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Asking

    /// Sends the draft. Returns the task running the turn so a caller (and a
    /// test) can wait for it.
    @discardableResult
    func send() -> Task<Void, Never>? {
        guard canSend else { return nil }
        let question = trimmedDraft
        draft = ""
        return ask(question)
    }

    @discardableResult
    func ask(_ question: String) -> Task<Void, Never>? {
        // While a past conversation loads, a question would go to the
        // thread on screen and then be replaced by the one arriving.
        guard !isResponding, !isLoadingConversation else { return nil }

        errorMessage = nil
        isResponding = true
        activity = nil
        turns.append(Turn(id: UUID().uuidString, role: .user, text: question))
        let answerID = UUID().uuidString
        turns.append(Turn(id: answerID, role: .assistant, text: "", isStreaming: true))

        let task = Task { [weak self] in
            guard let self else { return }
            await self.run(question: question, answerID: answerID)
        }
        responseTask = task
        return task
    }

    /// Stops the answer being written. Changes Flint already made stay made,
    /// and keep their Undo.
    func stop() {
        responseTask?.cancel()
    }

    private func run(question: String, answerID: String) async {
        defer {
            isResponding = false
            activity = nil
            responseTask = nil
        }

        let stream: AsyncThrowingStream<FlintAskStreamEvent, Error>
        do {
            stream = try await service.stream(message: question, conversationId: conversationId)
        } catch {
            await couldNotStart(error, question: question, answerID: answerID)
            return
        }

        var finished = false
        do {
            for try await event in stream {
                switch event {
                case .conversation(let id):
                    conversationId = id
                case .delta(let text):
                    activity = nil
                    update(answerID) { $0.text += text }
                case .activity(let label):
                    activity = label
                case .change(let change):
                    update(answerID) { turn in
                        if !turn.changes.contains(where: { $0.id == change.id }) {
                            turn.changes.append(change)
                        }
                    }
                case .done(let answer):
                    finished = true
                    conversationId = answer.conversationId ?? conversationId
                    update(answerID) { turn in
                        turn.text = answer.message.text
                        turn.references = answer.message.references
                        // The finished message carries every change; keep any
                        // Undo already run on this device.
                        turn.changes = answer.message.changes.map { change in
                            turn.changes.first(where: { $0.id == change.id && $0.undo.undone }) ?? change
                        }
                        turn.isStreaming = false
                    }
                case .failed(let message):
                    finished = true
                    fail(answerID, message: message)
                }
            }
        } catch {
            if Task.isCancelled || error.isAPICancellation {
                finished = true
                update(answerID) { turn in
                    turn.isStreaming = false
                    if turn.text.isEmpty { turn.text = "Stopped." }
                }
            } else {
                finished = true
                fail(answerID, message: "The connection dropped before Flint finished.")
            }
        }

        if !finished {
            if Task.isCancelled {
                update(answerID) { turn in
                    turn.isStreaming = false
                    if turn.text.isEmpty { turn.text = "Stopped." }
                }
            } else {
                fail(answerID, message: "Flint stopped before finishing.")
            }
        }
    }

    /// The server refused or could not be reached before any answer began.
    /// Nothing was changed, so it is safe to answer on the device instead.
    private func couldNotStart(_ error: Error, question: String, answerID: String) async {
        if Task.isCancelled || error.isAPICancellation {
            remove(answerID)
            return
        }

        if Self.allowsLocalFallback(error), let localAnswerer {
            activity = "Answering on this device"
            if let text = await localAnswerer.answer(question: question) {
                update(answerID) { turn in
                    turn.text = text
                    turn.source = .local
                    turn.isStreaming = false
                }
                return
            }
        }

        fail(answerID, message: Self.message(for: error, inConversation: conversationId != nil))
    }

    /// A local answer is offered when the server can't be reached, is
    /// unavailable, or has spent the day's allowance; not when it understood
    /// the request and refused it.
    static func allowsLocalFallback(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        switch apiError {
        case .transport, .noData:
            return true
        case .httpStatus(let status, _, _):
            return status == 429 || status >= 500
        default:
            return false
        }
    }

    /// `inConversation` says whether the request named a conversation: a 404
    /// then means that thread has gone. Without one, a 404 can only mean the
    /// server has no Ask Flint routes, which is a server still to be updated.
    static func message(for error: Error, inConversation: Bool = true) -> String {
        guard let apiError = error as? APIError else {
            return "Flint couldn't answer that just now."
        }
        switch apiError {
        case .httpStatus(429, _, _):
            return "Flint has used today's AI allowance. Try again tomorrow."
        case .httpStatus(404, _, _):
            return inConversation
                ? "That conversation is no longer available. Start a new one."
                : "Ask Flint isn't available on this Spark server yet. It needs updating."
        case .unauthorized:
            return "Sign in again to ask Flint."
        case .transport:
            return "Can't reach Spark. Check your connection and try again."
        default:
            return apiError.errorDescription ?? "Flint couldn't answer that just now."
        }
    }

    // MARK: - Undo

    func undo(_ change: FlintAskChange) async {
        guard let receiptId = change.receiptId, change.canUndo(), !undoingReceiptIDs.contains(receiptId) else { return }

        undoingReceiptIDs.insert(receiptId)
        defer { undoingReceiptIDs.remove(receiptId) }

        do {
            guard try await service.undo(receiptId: receiptId) else {
                errorMessage = "Couldn't undo that. Try again."
                return
            }
            errorMessage = nil
            for index in turns.indices {
                turns[index].changes = turns[index].changes.map { $0.id == change.id ? $0.markedUndone() : $0 }
            }
        } catch {
            errorMessage = "Couldn't undo that. \(Self.message(for: error))"
        }
    }

    // MARK: - History

    func startNewConversation() {
        stop()
        historyLoadID = nil
        isLoadingConversation = false
        turns = []
        conversationId = nil
        errorMessage = nil
        draft = ""
    }

    func loadConversations() async {
        historyState = .loading
        do {
            conversations = try await service.conversations()
            historyState = .loaded
        } catch {
            historyState = .error(Self.message(for: error, inConversation: false))
        }
    }

    func open(_ conversation: FlintAskConversation) async {
        stop()
        let loadID = UUID()
        historyLoadID = loadID
        isLoadingConversation = true
        defer {
            if historyLoadID == loadID {
                historyLoadID = nil
                isLoadingConversation = false
            }
        }

        do {
            let messages = try await service.messages(conversationId: conversation.id)
            guard historyLoadID == loadID else { return }
            conversationId = conversation.id
            errorMessage = nil
            turns = messages.map { message in
                Turn(
                    id: message.id ?? UUID().uuidString,
                    role: message.role,
                    text: message.text,
                    references: message.references,
                    changes: message.changes,
                    failed: message.status == "failed"
                )
            }
        } catch {
            guard historyLoadID == loadID else { return }
            errorMessage = Self.message(for: error)
        }
    }

    func delete(_ conversation: FlintAskConversation) async {
        do {
            try await service.delete(conversationId: conversation.id)
            conversations.removeAll { $0.id == conversation.id }
            if conversationId == conversation.id {
                startNewConversation()
            }
        } catch {
            historyState = .error(Self.message(for: error))
        }
    }

    // MARK: - Turn edits

    private func update(_ id: String, _ change: (inout Turn) -> Void) {
        guard let index = turns.firstIndex(where: { $0.id == id }) else { return }
        change(&turns[index])
    }

    private func remove(_ id: String) {
        turns.removeAll { $0.id == id }
    }

    private func fail(_ id: String, message: String) {
        update(id) { turn in
            turn.isStreaming = false
            turn.failed = true
            if turn.text.isEmpty { turn.text = message }
        }
        // An answer with nothing else in it shows the message itself; the
        // banner is for one that got part-way and keeps what it wrote.
        errorMessage = turns.first { $0.id == id }?.text == message ? nil : message
    }
}
