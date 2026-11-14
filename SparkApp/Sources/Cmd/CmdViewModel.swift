import Foundation
import Observation
import SparkKit

@MainActor
@Observable
final class CmdViewModel {
    struct Receipt: Equatable, Identifiable {
        let id: UUID
        let summary: String
        let undoToken: String?
        let isQueued: Bool
        /// Set when the command asks first; the receipt shows Confirm.
        var pendingConfirmation: CmdEntry? = nil
    }

    var input: String = ""
    /// True while a line is being routed or read: the input bar shows it.
    private(set) var isRouting = false
    /// Set once a log line has been read: the confirmation sheet opens on what was understood.
    var logPrefill: LogPrefill?
    var searchQuery: String?
    private(set) var receipt: Receipt?
    /// Set by a line that names a screen; CmdView hands it to the app and clears it.
    var pendingNavigation: CmdDestination?
    /// Set when a line is for Flint; CmdView opens the chat with it and
    /// clears it. Nothing is written or queued.
    var pendingAsk: String?
    private(set) var recents: [CmdRecentStore.Item]
    private(set) var queuedCount: Int

    private let submitter: any CmdSubmitting
    private let queue: CmdQueue
    private let recentStore: CmdRecentStore
    private let route: @Sendable (String) async -> CmdRouteDecision?
    private let structuredLog: @Sendable (String) async -> LogRequest?
    /// The line whose routing may still act. A newer line replaces it, so a
    /// slow older one can't open its sheet or chat over the newer one.
    private var routingID: UUID?

    /// Reads a line with the on-device model: TV, wine, beer, film or a board game, else a note, with the time
    /// and people it names. Nil when the model can't serve it.
    static let readStructuredLog: @Sendable (String) async -> LogRequest? = { text in
        guard let draft = try? await LogExtractionService.extract(from: text) else { return nil }
        return try? draft.request(text: text)
    }

    /// `route` decides a line the rules aren't sure about; nil from it means
    /// no model could, and the rules decide instead.
    init(
        submitter: any CmdSubmitting = StubCmdSubmitter(),
        queue: CmdQueue = CmdQueue(),
        recentStore: CmdRecentStore = CmdRecentStore(),
        route: @escaping @Sendable (String) async -> CmdRouteDecision? = CmdRoutingService.route,
        structuredLog: @escaping @Sendable (String) async -> LogRequest? = CmdViewModel.readStructuredLog
    ) {
        self.route = route
        self.structuredLog = structuredLog
        self.submitter = submitter
        self.queue = queue
        self.recentStore = recentStore
        recents = recentStore.load()
        queuedCount = queue.load().count
    }

    private var line: String { input.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSubmit: Bool { !line.isEmpty }

    /// A vertical-axis field can insert a newline for return instead of calling
    /// onSubmit. Call this after `input` changed: a lone inserted newline is
    /// dropped and the line is sent. Runs from onChange so the field is cleared
    /// after SwiftUI has applied the edit, not during it.
    func inputChanged(from previous: String) {
        let added = input.filter { $0 == "\n" }.count - previous.filter { $0 == "\n" }.count
        guard added == 1, input.replacingOccurrences(of: "\n", with: "") == previous.replacingOccurrences(of: "\n", with: "")
        else { return }
        input = previous
        submit()
    }

    /// Sends the line to be routed. Returns the task doing it, so a test can wait.
    @discardableResult
    func submit() -> Task<Void, Never>? {
        let text = line
        guard !text.isEmpty else { return nil }
        input = ""
        let id = UUID()
        routingID = id
        isRouting = true
        return Task { await run(text, id: id) }
    }

    /// Decides where the line goes and opens it: the Log sheet, a screen, or
    /// the Flint chat. Nothing is written here; the sheet and the chat do that.
    private func run(_ text: String, id: UUID) async {
        defer {
            if routingID == id {
                routingID = nil
                isRouting = false
            }
        }

        let decision: CmdRouteDecision
        if let certain = CmdRouter.certain(text) {
            decision = certain
        } else if let routed = await route(text) {
            decision = routed
        } else {
            decision = CmdRouter.fallback(text)
        }
        guard routingID == id else { return }

        switch decision {
        case .flint:
            recents = recentStore.record(text: text, intent: .ask)
            pendingAsk = text
        case .navigate(let destination):
            recents = recentStore.record(text: text, intent: .command)
            pendingNavigation = destination
        case .log:
            recents = recentStore.record(text: text, intent: .log)
            // The model reads what it was, when, and who with; the sheet
            // checks the names. Without the model the line is a note.
            let request = await structuredLog(text) ?? Self.note(text)
            guard routingID == id else { return }
            logPrefill = LogPrefill(text: text, request: request)
        }
    }

    static func note(_ text: String) -> LogRequest {
        LogRequest(kind: .reflection, title: "", body: text)
    }

    /// The confirmation sheet couldn't send a checked log: keep it and send it with the rest of the queue.
    /// Its idempotency key becomes the entry id, so a write that did land is replayed, not repeated.
    func queueLog(_ request: LogRequest, text: String) {
        let entry = CmdEntry(
            id: UUID(uuidString: request.idempotencyKey) ?? UUID(), intent: .log, text: text,
            classifiedAs: .log, log: request)
        queue.enqueue(entry)
        queuedCount = queue.load().count
    }

    func openSearch(_ query: String = "") {
        searchQuery = query
    }

    func useRecent(_ item: CmdRecentStore.Item) {
        input = item.text
    }

    func undo() {
        guard let token = receipt?.undoToken else { return }
        receipt = nil
        Task {
            guard await submitter.undo(token: token) == false else { return }
            receipt = Receipt(id: UUID(), summary: "Couldn't undo", undoToken: nil, isQueued: false)
        }
    }

    func confirmPending() {
        guard let entry = receipt?.pendingConfirmation else { return }
        receipt = nil
        Task { await deliver(entry.confirming()) }
    }

    func dismissReceipt() { receipt = nil }

    func flushQueue() async {
        guard !queue.load().isEmpty else { return }
        let sent = await queue.flush(using: submitter)
        queuedCount = queue.load().count
        for (entry, result) in sent {
            switch result {
            case .needsConfirmation(let prompt):
                receipt = Receipt(
                    id: entry.id, summary: prompt, undoToken: nil, isQueued: false, pendingConfirmation: entry)
            case .rejected(let reason):
                receipt = Receipt(id: entry.id, summary: reason, undoToken: nil, isQueued: false)
            case .done, .retry, .navigate:
                break
            }
        }
    }

    func clearLocalState() {
        queue.clear()
        recentStore.clear()
        recents = []
        queuedCount = 0
    }

    private func deliver(_ entry: CmdEntry) async {
        switch await submitter.submit(entry) {
        case .done(let summary, let undoToken):
            receipt = Receipt(id: entry.id, summary: summary, undoToken: undoToken, isQueued: false)
        case .retry:
            queue.enqueue(entry)
            queuedCount = queue.load().count
            receipt = Receipt(id: entry.id, summary: "Queued", undoToken: nil, isQueued: true)
        case .needsConfirmation(let prompt):
            receipt = Receipt(
                id: entry.id, summary: prompt, undoToken: nil, isQueued: false, pendingConfirmation: entry)
        case .rejected(let reason):
            receipt = Receipt(id: entry.id, summary: reason, undoToken: nil, isQueued: false)
        case .navigate(let destination):
            receipt = nil
            pendingNavigation = destination
        }
    }
}
