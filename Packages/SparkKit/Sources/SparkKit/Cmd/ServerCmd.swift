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
        guard let intent = Self.intent(from: response.intent), !response.needsChoice else {
            // `unsure`: keep the text, drop below the threshold so the app asks.
            return CmdClassification(intent: local.intent, confidence: 0, text: response.text)
        }
        return CmdClassification(
            intent: intent, confidence: response.confidence, text: response.text, isForced: response.confidence >= 1)
    }

    static func wire(_ intent: CmdIntent) -> String {
        intent == .flintNote ? "flint_note" : intent.rawValue
    }

    static func intent(from wire: String) -> CmdIntent? {
        wire == "flint_note" ? .flintNote : CmdIntent(rawValue: wire)
    }
}

/// Commits entries. A note for Flint is written by the server. Free-text
/// log and commands have no write path yet (no `kind` for `POST /log`; the
/// action registry is not wired in), so they are refused rather than
/// reported as done.
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
            return .rejected(reason: "Free-text log isn't available yet")
        case .command:
            return .rejected(reason: "Commands aren't available yet")
        case .search:
            return .done(summary: "", undoToken: nil)
        }
    }

    public func undo(token: String) async -> Bool { false }

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
