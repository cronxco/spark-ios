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

    static let characterLimit = 300

    var text = ""
    private(set) var phase: Phase = .idle
    private(set) var undoError: String?

    /// What was understood, shown for checking and fixing before anything is logged.
    var draft = LogRequest(kind: .wine, title: "")

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
        phase = .preview
    }

    /// Logs what the preview shows, with any fixes made to it.
    func confirm(using apiClient: APIClient) async {
        guard case .preview = phase, canConfirm else { return }

        var request = draft
        request.title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        await send(request, using: apiClient)
    }

    /// Back to the text, keeping what was typed.
    func edit() {
        guard case .preview = phase else { return }
        phase = .idle
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
            case .needsClarification(let question):
                phase = .question(question)
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
