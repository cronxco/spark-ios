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
    /// Set while an ambiguous `@mention` waits for the user to pick a person.
    private(set) var pickingMention: CmdMention?
    var searchQuery: String?
    private(set) var receipt: Receipt?
    private(set) var recents: [CmdRecentStore.Item]
    private(set) var queuedCount: Int

    private let classifier: any CmdClassifying
    private let submitter: any CmdSubmitting
    private let queue: CmdQueue
    private let recentStore: CmdRecentStore
    private var classifyTask: Task<Void, Never>?
    private var mentionPicks: [String: CmdMentionPick] = [:]
    private var pendingSend: (intent: CmdIntent, classification: CmdClassification)?

    init(
        classifier: any CmdClassifying = HeuristicCmdClassifier(),
        submitter: any CmdSubmitting = StubCmdSubmitter(),
        queue: CmdQueue = CmdQueue(),
        recentStore: CmdRecentStore = CmdRecentStore()
    ) {
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

    /// The pick sheet's answer for the mention it is showing.
    func resolveMention(_ pick: CmdMentionPick) {
        guard let mention = pickingMention, let pending = pendingSend else { return }
        mentionPicks[mention.name] = pick
        pickingMention = nil
        pendingSend = nil
        send(intent: pending.intent, classification: pending.classification)
    }

    func cancelMention() {
        pickingMention = nil
        pendingSend = nil
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
            case .done, .retry:
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
        var links: CmdPersonLinks?
        if intent == .log, !classification.mentions.isEmpty {
            links = CmdPersonLinks.resolve(classification.mentions, picks: mentionPicks)
            if links == nil {
                // Several people fit: ask before saving, nothing is written yet.
                pendingSend = (intent, classification)
                pickingMention = CmdPersonLinks.unresolved(classification.mentions, picks: mentionPicks)
                return
            }
        }
        let entry = CmdEntry(
            intent: intent, text: text, classifiedAs: classification.intent, confidence: classification.confidence,
            personIds: links?.ids, newPeople: links?.newNames)
        recents = recentStore.record(text: text, intent: intent)
        reset()
        Task { await deliver(entry) }
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
        }
    }

    private func reset() {
        input = ""
        override = nil
        isAsking = false
        mentionPicks = [:]
        pendingSend = nil
        pickingMention = nil
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
