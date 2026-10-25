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

    var input: String = "" {
        didSet { reclassify() }
    }
    private(set) var classification: CmdClassification?
    /// Set when the user picks an intent on the chip or in the ask sheet.
    private(set) var override: CmdIntent?
    var isAsking = false
    /// Set once a log line has been read: the confirmation sheet opens on what was understood.
    var logPrefill: LogPrefill?
    var searchQuery: String?
    private(set) var receipt: Receipt?
    /// Set by a navigation command; CmdView hands it to the app and clears it.
    var pendingNavigation: CmdDestination?
    private(set) var recents: [CmdRecentStore.Item]
    private(set) var queuedCount: Int

    private let classifier: any CmdClassifying
    private let submitter: any CmdSubmitting
    private let queue: CmdQueue
    private let recentStore: CmdRecentStore
    private let structuredLog: @Sendable (String) async -> LogRequest?
    private var classifyTask: Task<Void, Never>?
    /// The log read that may open the sheet. A newer line replaces it, so a slow older read can't overwrite it.
    private var logReadID: UUID?

    /// Reads a line with the on-device model: TV, wine, beer, film or a board game, else a note, with the time
    /// and people it names. Nil when the model can't serve it.
    static let readStructuredLog: @Sendable (String) async -> LogRequest? = { text in
        guard let draft = try? await LogExtractionService.extract(from: text) else { return nil }
        return try? draft.request(text: text)
    }

    init(
        classifier: any CmdClassifying = HeuristicCmdClassifier(),
        submitter: any CmdSubmitting = StubCmdSubmitter(),
        queue: CmdQueue = CmdQueue(),
        recentStore: CmdRecentStore = CmdRecentStore(),
        structuredLog: @escaping @Sendable (String) async -> LogRequest? = CmdViewModel.readStructuredLog
    ) {
        self.structuredLog = structuredLog
        self.classifier = classifier
        self.submitter = submitter
        self.queue = queue
        self.recentStore = recentStore
        recents = recentStore.load()
        queuedCount = queue.load().count
    }

    /// The intent that will run: the user's pick, else the classifier's.
    var effectiveIntent: CmdIntent? { override ?? classification?.intent }

    var canSubmit: Bool { effectiveIntent != nil }

    func choose(_ intent: CmdIntent) {
        override = intent
    }

    func submit() {
        guard let classification else { return }
        if override == nil, classification.needsAsk {
            isAsking = true
            return
        }
        send(intent: override ?? classification.intent, classification: classification)
    }

    /// The ask sheet's one-tap choice. Nothing was written before this.
    func resolveAsk(_ intent: CmdIntent) {
        isAsking = false
        guard let classification else { return }
        send(intent: intent, classification: classification)
    }

    /// One line under the input saying who a log will link to.
    var mentionSummary: String? {
        guard effectiveIntent == .log, let mentions = classification?.mentions, !mentions.isEmpty else { return nil }
        let parts = mentions.map { mention -> String in
            switch mention.state {
            case .existing: return mention.matches.first?.name ?? mention.displayName
            case .likely: return "\(mention.displayName) → \(mention.matches.first?.name ?? mention.displayName)"
            case .ambiguous: return "\(mention.displayName)?"
            case .new: return "\(mention.displayName) (new)"
            }
        }
        return "With " + parts.joined(separator: ", ")
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
        override = item.intent
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

    private func send(intent: CmdIntent, classification: CmdClassification) {
        let text = classification.text
        if intent == .search {
            recents = recentStore.record(text: text, intent: .search)
            reset()
            openSearch(text)
            return
        }
        recents = recentStore.record(text: text, intent: intent)
        reset()
        if intent == .log {
            Task { await readLog(text, mentions: classification.mentions) }
            return
        }
        let entry = CmdEntry(
            intent: intent, text: text, classifiedAs: classification.intent, confidence: classification.confidence)
        Task { await deliver(entry) }
    }

    /// Every log line opens the confirmation sheet before anything is written. The model reads what it was
    /// (a note, TV, wine, beer, film, a board game), when, and who with; the sheet checks the names and any
    /// match. When the model can't serve it, the line is a note with its `@mentions` as the people.
    private func readLog(_ text: String, mentions: [CmdMention]) async {
        let id = UUID()
        logReadID = id
        receipt = Receipt(id: id, summary: "Reading", undoToken: nil, isQueued: false)
        let request = await structuredLog(text) ?? Self.note(text, mentions: mentions)
        guard logReadID == id else { return }
        logReadID = nil
        if receipt?.id == id { receipt = nil }
        logPrefill = LogPrefill(text: text, request: request)
    }

    static func note(_ text: String, mentions: [CmdMention]) -> LogRequest {
        var names: [String] = []
        for mention in mentions {
            let name = mention.state == .existing || mention.state == .likely
                ? mention.matches.first?.name ?? mention.displayName
                : mention.displayName
            if !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) { names.append(name) }
        }
        return LogRequest(kind: .reflection, title: "", people: names.isEmpty ? nil : names, body: text)
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

    private func reset() {
        input = ""
        override = nil
        isAsking = false
    }

    private func reclassify() {
        classifyTask?.cancel()
        let text = input
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            classification = nil
            override = nil
            return
        }
        // The chip answers at once from the rules; the classifier refines it.
        classification = HeuristicCmdClassifier.classifySync(text)
        classifyTask = Task { [classifier] in
            let result = await classifier.classify(text)
            guard !Task.isCancelled, let result else { return }
            self.classification = result
        }
    }
}
