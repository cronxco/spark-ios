import Foundation

/// Asks the server to classify, passing the local rules' guess as the hint.
/// The server decides `@flint`, prefixes and the confidence threshold; when
/// it can't be reached the local guess stands.
public struct ServerCmdClassifier: CmdClassifying {
    private let apiClient: APIClient
    private let debounce: Duration

    public init(apiClient: APIClient, debounce: Duration = .milliseconds(400)) {
        self.apiClient = apiClient
        self.debounce = debounce
    }

    public func classify(_ input: String) async -> CmdClassification? {
        let local = HeuristicCmdClassifier.classifySync(input)
        guard let local else { return nil }
        // Cancelled by the next keystroke before anything is sent.
        do { try await Task.sleep(for: debounce) } catch { return local }

        let hint = QuickLogIntentsEndpoint.Hint(intent: Self.wire(local.intent), confidence: local.confidence)
        let request = QuickLogIntentsEndpoint.ClassifyRequest(text: local.text, hint: hint)
        guard let response = try? await apiClient.request(QuickLogIntentsEndpoint.classify(request)) else {
            return local
        }
        let mentions = Self.mentions(from: response.people)
        guard let intent = Self.intent(from: response.intent), !response.needsChoice else {
            // `unsure`: keep the text, drop below the threshold so the app asks.
            return CmdClassification(intent: local.intent, confidence: 0, text: response.text, mentions: mentions)
        }
        return CmdClassification(
            intent: intent, confidence: response.confidence, text: response.text,
            isForced: response.confidence >= 1, mentions: mentions)
    }

    static func mentions(from people: [QuickLogIntentsEndpoint.Mention]) -> [CmdMention] {
        people.compactMap { person in
            guard let state = CmdMention.State(rawValue: person.state) else { return nil }
            return CmdMention(
                name: person.name, state: state,
                matches: person.matches.map { CmdMention.Match(id: $0.id, name: $0.name) })
        }
    }

    static func wire(_ intent: CmdIntent) -> String {
        intent == .flintNote ? "flint_note" : intent.rawValue
    }

    static func intent(from wire: String) -> CmdIntent? {
        wire == "flint_note" ? .flintNote : CmdIntent(rawValue: wire)
    }
}

/// Commits entries. A note for Flint is written by the server and a command
/// runs through the action registry. A free-text log
/// is saved as a reflection.
public struct ServerCmdSubmitter: CmdSubmitting {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func submit(_ entry: CmdEntry) async -> CmdSubmissionResult {
        switch entry.intent {
        case .flintNote:
            return await commit(entry)
        case .log:
            if let log = entry.log { return await submitLog(log, id: entry.id) }
            return await logReflection(entry)
        case .command:
            return await runCommand(entry)
        case .search:
            return .done(summary: "", undoToken: nil)
        }
    }

    public func undo(token: String) async -> Bool {
        guard let receipt = try? await apiClient.request(CmdActionsEndpoint.undo(receiptId: token)) else { return false }
        return receipt.status == "succeeded"
    }

    /// A plain line becomes a reflection. Wine, beer and TV drafts go through
    /// their own structured flow, not here. `@mentions` stay in the text and
    /// the people the app settled on are linked to the event.
    private func logReflection(_ entry: CmdEntry) async -> CmdSubmissionResult {
        let request = LogEndpoint.ReflectionRequest(
            idempotencyKey: entry.id.uuidString, body: entry.text, occurredAt: entry.createdAt,
            personIds: entry.personIds ?? [], newPeople: entry.newPeople ?? [])
        do {
            _ = try await apiClient.request(LogEndpoint.reflection(request))
            return .done(summary: "Logged", undoToken: nil)
        } catch let error as APIError {
            return Self.result(for: error, rejection: "Couldn't log")
        } catch {
            return .retry
        }
    }

    /// A log checked on the confirmation sheet that couldn't be sent then. The entry id is the idempotency key,
    /// so a retry replays the first write. A TV question can't be asked from the queue, so it is turned down.
    private func submitLog(_ log: LogRequest, id: UUID) async -> CmdSubmissionResult {
        var request = log
        request.idempotencyKey = id.uuidString
        request.dryRun = nil
        do {
            switch try await apiClient.request(LogEndpoint.submit(request)) {
            case .logged:
                return .done(summary: "Logged", undoToken: nil)
            case .needsClarification, .preview:
                return .rejected(reason: "Couldn't log \(log.kind == .reflection ? "that" : log.title): open Log to finish it")
            }
        } catch let error as APIError {
            return Self.result(for: error, rejection: "Couldn't log")
        } catch {
            return .retry
        }
    }

    private static func result(for error: APIError, rejection: String) -> CmdSubmissionResult {
        switch error {
        case .httpStatus(let code, _, _) where (400..<500).contains(code) && code != 408 && code != 429:
            return .rejected(reason: rejection)
        default:
            return .retry
        }
    }

    /// Finds the registry action named by the text and runs it. Navigation
    /// and actions that need a target (an event, an integration) aren't
    /// runnable from a typed line yet.
    private func runCommand(_ entry: CmdEntry) async -> CmdSubmissionResult {
        guard !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .rejected(reason: "No matching command")
        }
        let found: [CmdActionsEndpoint.Action]
        do {
            found = try await apiClient.request(CmdActionsEndpoint.list(query: entry.text)).data
        } catch {
            return .retry
        }
        // Exact title only: a fuzzy first hit could run the wrong action.
        let query = entry.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty, let action = found.first(where: { $0.title.lowercased() == query }) else {
            return .rejected(reason: "No matching command")
        }
        guard action.kind != "navigation", action.runsWithoutInput else {
            return .rejected(reason: "Can't run that from here yet")
        }

        let confirmed = entry.confirmed ?? false
        do {
            let receipt = try await apiClient.request(
                CmdActionsEndpoint.run(id: action.id, confirmed: confirmed, idempotencyKey: entry.id.uuidString))
            if receipt.status == "failed" { return .rejected(reason: receipt.message ?? "Failed") }
            let undoable = receipt.undo?.available == true
            return .done(summary: receipt.message ?? action.title, undoToken: undoable ? receipt.receiptId : nil)
        } catch let error as APIError {
            switch error {
            case .httpStatus(409, _, _): return .needsConfirmation(prompt: action.title)
            case .httpStatus(403, _, _): return .rejected(reason: "Not allowed")
            case .httpStatus(let code, _, _) where (400..<500).contains(code) && code != 408 && code != 429:
                return .rejected(reason: "Couldn't run it")
            default: return .retry
            }
        } catch {
            return .retry
        }
    }

    private func commit(_ entry: CmdEntry) async -> CmdSubmissionResult {
        let request = QuickLogIntentsEndpoint.CommitRequest(
            idempotencyKey: entry.id.uuidString,
            text: entry.text,
            intent: ServerCmdClassifier.wire(entry.intent),
            suggestedIntent: entry.classifiedAs.map(ServerCmdClassifier.wire),
            confidence: entry.confidence,
            occurredAt: entry.createdAt
        )
        do {
            _ = try await apiClient.request(QuickLogIntentsEndpoint.commit(request))
            return .done(summary: "Noted for Flint", undoToken: nil)
        } catch let error as APIError {
            switch error {
            case .httpStatus(403, _, _): return .rejected(reason: "Not allowed to write Flint notes")
            case .httpStatus(let code, _, _) where (400..<500).contains(code) && code != 408 && code != 429:
                return .rejected(reason: "Couldn't save")
            default: return .retry
            }
        } catch {
            return .retry
        }
    }
}
