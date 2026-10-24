import Foundation
import Observation
import SparkKit

@MainActor
@Observable
final class LogViewModel {
    struct Outcome: Equatable {
        var events: [LoggedEvent]
        var missingEpisodes: [Int]
        var people: [LoggedPerson] = []
    }

    enum Phase: Equatable {
        case idle
        case working(String)
        case preview
        case question(LogClarification)
        case logged(Outcome)
        case undone
        case failed(String)
    }

    /// What a dry run found for the preview: the Vivino or Untappd card, or the TheTVDB series, season and episodes.
    enum MatchState: Equatable {
        case idle
        case loading
        /// Nil when there is nothing to look up (cinema, board games).
        case loaded(LogMatch?)
        /// TV that needs a series or season picked before it can be matched.
        case question(LogClarification)
        case failed
    }

    static let characterLimit = 300

    var text = ""
    private(set) var phase: Phase = .idle
    private(set) var undoError: String?

    /// What was understood, shown for checking and fixing before anything is logged.
    var draft = LogRequest(kind: .wine, title: "")
    private(set) var matchState: MatchState = .idle
    /// A runner-up the user picked over the best card.
    private(set) var chosenCard: LogMatch.Card?
    /// How each typed name matched a known person, keyed by the lowercased name.
    private(set) var personChecks: [String: LogPersonCheck] = [:]
    /// Names the user wants as a new person even though someone similar exists, lowercased.
    private var newPeople: Set<String> = []

    /// The request waiting on an answer. Answers amend it and resend under the same idempotency key.
    private var pending: LogRequest?

    private let extract: @Sendable (String) async throws -> LogDraft

    init(extract: @escaping @Sendable (String) async throws -> LogDraft = { try await LogExtractionService.extract(from: $0) }) {
        self.extract = extract
    }

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isWorking: Bool {
        if case .working = phase { return true }
        return false
    }

    var canSubmit: Bool { !trimmedText.isEmpty && !isWorking }

    /// Changes whenever something the lookup depends on does, so the sheet can search again.
    var matchKey: String {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(draft.kind.rawValue)|\(title)|\(draft.season ?? 0)|\(draft.episodes ?? [])|\(draft.tvdbID ?? 0)"
    }

    /// Changes when the people named change, so the sheet can check them again.
    var peopleKey: String {
        (draft.people ?? []).map { $0.lowercased() }.joined(separator: "|")
    }

    /// A name that could be one of several people, or a short form of one, and has not been settled.
    var hasUnresolvedPeople: Bool {
        (draft.people ?? []).contains { isUnresolved($0) }
    }

    func isUnresolved(_ name: String) -> Bool {
        guard let check = personChecks[name.lowercased()], !newPeople.contains(name.lowercased()) else { return false }
        return check.state == .likely || check.state == .ambiguous
    }

    func personCheck(for name: String) -> LogPersonCheck? {
        personChecks[name.lowercased()]
    }

    func isNewPerson(_ name: String) -> Bool {
        newPeople.contains(name.lowercased())
    }

    var canConfirm: Bool { !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func updateText(_ value: String) {
        text = String(value.prefix(Self.characterLimit))
        if case .failed = phase { phase = .idle }
    }

    func submit(using apiClient: APIClient, now: Date = .now) async {
        guard canSubmit else { return }

        phase = .working("Reading")
        let request: LogRequest
        do {
            let draft = try await extract(trimmedText)
            request = try draft.request(now: now)
        } catch LogExtractionError.unavailable {
            phase = .failed("Apple Intelligence isn’t available.")
            return
        } catch LogDraftIssue.missingTitle, LogDraftIssue.unknownKind {
            phase = .failed("What was it?")
            return
        } catch LogDraftIssue.missingEpisodes {
            phase = .failed("Which episodes?")
            return
        } catch where error.isAPICancellation {
            phase = .idle
            return
        } catch {
            phase = .failed("Couldn’t read that. Try again.")
            return
        }

        draft = request
        matchState = .idle
        chosenCard = nil
        phase = .preview
    }

    /// Asks the backend what this would match. Waits briefly first so typing in the name does not search on every key.
    func refreshMatch(using apiClient: APIClient) async {
        guard case .preview = phase, canConfirm else { return }

        guard draft.kind != .cinema, draft.kind != .boardGame else {
            matchState = .loaded(nil)
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(600))
        } catch {
            return
        }

        matchState = .loading
        chosenCard = nil
        draft.matchURL = nil

        var request = draft
        request.dryRun = true
        do {
            switch try await apiClient.request(LogEndpoint.submit(request)) {
            case .preview(let match, _):
                matchState = .loaded(match)
            case .needsClarification(let question, _):
                matchState = .question(question)
            case .logged:
                matchState = .failed
            }
        } catch where error.isAPICancellation {
            return
        } catch {
            matchState = .failed
        }
    }

    /// Answers the series or season question in the preview. The changed draft makes the sheet search again.
    func answerMatchQuestion(_ option: LogClarification.Option) {
        guard case .question(let question) = matchState else { return }

        switch question.field {
        case .series: draft.tvdbID = option.value
        case .season: draft.season = option.value
        }
    }

    /// Uses a runner-up instead of the best card: enrichment follows this one.
    func chooseMatch(_ card: LogMatch.Card?) {
        chosenCard = card
        draft.matchURL = card?.url
    }

    /// Logs what the preview shows, with any fixes made to it.
    func confirm(using apiClient: APIClient) async {
        guard case .preview = phase, canConfirm, !hasUnresolvedPeople else { return }

        var request = draft
        request.title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        await send(request, using: apiClient)
    }

    /// Back to the text, keeping what was typed.
    func edit() {
        guard case .preview = phase else { return }
        phase = .idle
    }

    /// Asks which of the named people are already known. Only the people go over, so nothing is looked up on a site.
    func refreshPeople(using apiClient: APIClient) async {
        guard case .preview = phase, let names = draft.people, !names.isEmpty else {
            personChecks = [:]
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(400))
        } catch {
            return
        }

        var request = LogRequest(kind: .cinema, title: draft.title, people: names)
        request.dryRun = true
        do {
            let response = try await apiClient.request(LogEndpoint.submit(request))
            guard case .preview(_, let checks) = response else { return }
            personChecks = Dictionary(checks.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
            normaliseExactMatches(checks)
        } catch {
            personChecks = [:]
        }
    }

    /// Settles a likely or ambiguous name as the known person picked.
    func resolvePerson(_ name: String, as match: LogPersonCheck.Match) {
        replacePerson(name, with: match.name)
    }

    /// Keeps a typed name as a new person even though someone similar exists.
    func keepNewPerson(_ name: String) {
        newPeople.insert(name.lowercased())
    }

    private func normaliseExactMatches(_ checks: [LogPersonCheck]) {
        for check in checks where check.state == .existing {
            guard let known = check.matches.first?.name, known != check.name else { continue }
            replacePerson(check.name, with: known)
        }
    }

    private func replacePerson(_ name: String, with other: String) {
        var names = draft.people ?? []
        guard let index = names.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return }

        if names.contains(where: { $0.caseInsensitiveCompare(other) == .orderedSame && $0 != names[index] }) {
            names.remove(at: index)
        } else {
            names[index] = other
        }
        draft.people = names.nilIfEmpty
        newPeople.remove(name.lowercased())
    }

    func removePerson(_ name: String) {
        draft.people = draft.people?.filter { $0 != name }.nilIfEmpty
    }

    func addPerson(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var names = draft.people ?? []
        guard !trimmed.isEmpty, trimmed.count <= 100, names.count < 10,
              !names.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
        else { return }
        names.append(trimmed)
        draft.people = names
    }

    /// Answers the question on screen: the chosen series or season is added to the waiting request.
    func answer(_ option: LogClarification.Option, using apiClient: APIClient) async {
        guard case .question(let question) = phase, var request = pending else { return }

        switch question.field {
        case .series: request.tvdbID = option.value
        case .season: request.season = option.value
        }

        await send(request, using: apiClient)
    }

    /// Deletes what was just logged. The events are soft-deleted, so nothing is lost for good.
    func undo(using apiClient: APIClient) async {
        guard case .logged(let outcome) = phase else { return }

        undoError = nil
        phase = .working("Removing")
        var remaining = outcome
        do {
            for event in outcome.events {
                let current = try await apiClient.requestWithRawResponse(
                    EntityMutationsEndpoint.detailForWrite(kind: .events, id: event.id, response: LogEventVersion.self)
                )
                guard let version = current.etag else { throw LogUndoError.missingVersion }
                _ = try await apiClient.request(EventsEndpoint.delete(id: event.id, etag: version))
                remaining.events.removeAll { $0.id == event.id }
            }
            pending = nil
            phase = .undone
        } catch where error.isAPICancellation {
            phase = .logged(remaining)
        } catch {
            SparkObservability.captureHandled(error)
            phase = .logged(remaining)
            undoError = "Couldn’t remove it. Try again."
        }
    }

    func reset() {
        personChecks = [:]
        newPeople = []
        matchState = .idle
        chosenCard = nil
        text = ""
        pending = nil
        undoError = nil
        phase = .idle
    }

    private func send(_ request: LogRequest, using apiClient: APIClient) async {
        pending = request
        phase = .working("Logging")

        do {
            switch try await apiClient.request(LogEndpoint.submit(request)) {
            case .logged(let events, let missingEpisodes, let people):
                pending = nil
                phase = .logged(Outcome(events: events, missingEpisodes: missingEpisodes, people: people))
            case .needsClarification(let question, _):
                phase = .question(question)
            case .preview:
                phase = .failed("Couldn’t log that. Try again.")
            }
        } catch where error.isAPICancellation {
            phase = .idle
        } catch {
            SparkObservability.captureHandled(error)
            phase = .failed(Self.userFacingError(error))
        }
    }

    private enum LogUndoError: Error {
        case missingVersion
    }

    private static func userFacingError(_ error: Error) -> String {
        if case APIError.httpStatus(403, _, _) = error {
            return "This session can’t log."
        }
        if case APIError.httpStatus(422, let data, _) = error, let message = serverMessage(in: data) {
            return message
        }
        return "Couldn’t log that. Try again."
    }

    private static func serverMessage(in data: Data?) -> String? {
        guard
            let data,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = object["message"] as? String,
            !message.isEmpty
        else { return nil }
        return message
    }
}

private extension Array {
    var nilIfEmpty: [Element]? { isEmpty ? nil : self }
}
