import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("CMD structured log", .serialized)
@MainActor
struct CmdStructuredLogTests {
    private final class RecordingSubmitter: CmdSubmitting, @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [CmdEntry] = []

        var submitted: [CmdEntry] { lock.withLock { entries } }

        func submit(_ entry: CmdEntry) async -> CmdSubmissionResult {
            lock.withLock { entries.append(entry) }
            return .done(summary: "Logged", undoToken: nil)
        }

        func undo(token: String) async -> Bool { true }
    }

    private static let line = "Watched the diplomat episodes 7 and 8 with Dan this evening"

    private func makeModel(
        submitter: RecordingSubmitter, structuredLog: @escaping @Sendable (String) async -> LogRequest?
    ) -> CmdViewModel {
        let suite = "spark.cmd.structured.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return CmdViewModel(
            classifier: HeuristicCmdClassifier(),
            submitter: submitter,
            queue: CmdQueue(defaults: defaults),
            recentStore: CmdRecentStore(defaults: defaults),
            structuredLog: structuredLog
        )
    }

    private func settle(_ model: CmdViewModel, until done: @MainActor () -> Bool) async {
        for _ in 0..<200 where !done() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test("a TV line opens the Log preview and writes nothing")
    func tvLineOpensPreview() async {
        let submitter = RecordingSubmitter()
        let request = LogRequest(kind: .tv, title: "The Diplomat", episodes: [7, 8], people: ["Dan"])
        let model = makeModel(submitter: submitter) { _ in request }

        model.input = Self.line
        model.submit()
        await settle(model) { model.logPrefill != nil }

        #expect(model.logPrefill?.request.title == "The Diplomat")
        #expect(model.logPrefill?.request.people == ["Dan"])
        #expect(model.logPrefill?.text == Self.line)
        #expect(submitter.submitted.isEmpty)
        #expect(model.receipt == nil)
    }

    @Test("a plain line opens the sheet as a note, with its time and people, and writes nothing")
    func plainLineOpensNote() async {
        let submitter = RecordingSubmitter()
        let evening = Date(timeIntervalSince1970: 1_000_000)
        let note = LogRequest(kind: .reflection, title: "", occurredAt: evening, people: ["Dan"], body: "Went to Drop Project with Dan")
        let model = makeModel(submitter: submitter) { _ in note }

        model.input = "Went to Drop Project with Dan"
        model.submit()
        await settle(model) { model.logPrefill != nil }

        #expect(model.logPrefill?.request.kind == .reflection)
        #expect(model.logPrefill?.request.body == "Went to Drop Project with Dan")
        #expect(model.logPrefill?.request.occurredAt == evening)
        #expect(model.logPrefill?.request.people == ["Dan"])
        #expect(submitter.submitted.isEmpty)
    }

    @Test("without the model a line is still a note, with its @mentions as people")
    func modelUnavailableFallsBackToNote() {
        let mentions = [
            CmdMention(name: "dan", state: .likely, matches: [.init(id: "p1", name: "Daniel")]),
            CmdMention(name: "sam", state: .new, matches: []),
            CmdMention(name: "jo", state: .ambiguous, matches: [.init(id: "p2", name: "Joanna"), .init(id: "p3", name: "Joseph")]),
        ]

        let note = CmdViewModel.note("Lunch with @dan @sam @jo", mentions: mentions)

        #expect(note.kind == .reflection)
        #expect(note.body == "Lunch with @dan @sam @jo")
        #expect(note.people == ["Daniel", "Sam", "Jo"])
    }

    @Test("a log the sheet couldn't send is queued under its idempotency key")
    func queuedLogKeepsItsKey() {
        let submitter = RecordingSubmitter()
        let suite = "spark.cmd.structured.queue.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let queue = CmdQueue(defaults: defaults)
        let model = CmdViewModel(
            classifier: HeuristicCmdClassifier(), submitter: submitter, queue: queue,
            recentStore: CmdRecentStore(defaults: defaults), structuredLog: { _ in nil })
        let key = UUID()
        let request = LogRequest(kind: .tv, idempotencyKey: key.uuidString, title: "The Diplomat", episodes: [7, 8])

        model.queueLog(request, text: "Watched The Diplomat 7 and 8")

        let queued = queue.load()
        #expect(queued.count == 1)
        #expect(queued.first?.id == key)
        #expect(queued.first?.log == request)
        #expect(model.queuedCount == 1)
    }

    @Test("a note for Flint is never read as a log")
    func flintNoteSkipsReading() async {
        let submitter = RecordingSubmitter()
        let model = makeModel(submitter: submitter) { _ in
            Issue.record("A Flint note should not be read as a log")
            return LogRequest(kind: .tv, title: "x", episodes: [1])
        }

        model.input = "@flint remember to watch The Diplomat"
        model.submit()
        await settle(model) { !submitter.submitted.isEmpty }

        #expect(submitter.submitted.map(\.intent) == [.flintNote])
        #expect(model.logPrefill == nil)
    }
}

@Suite("Log view model prefill")
@MainActor
struct LogPrefillTests {
    @Test("start opens on the preview with what was read")
    func startOpensPreview() {
        let model = LogViewModel(extract: { _ in
            Issue.record("A prefilled line should not be read again")
            return LogDraft(kind: "tv", title: "x", episodes: [1])
        })
        let request = LogRequest(kind: .tv, title: "The Diplomat", episodes: [7, 8], people: ["Dan"])

        model.start(text: "Watched the diplomat episodes 7 and 8 with Dan", request: request)

        #expect(model.phase == .preview)
        #expect(model.draft.title == "The Diplomat")
        #expect(model.draft.episodes == [7, 8])
        #expect(model.text == "Watched the diplomat episodes 7 and 8 with Dan")
    }

    @Test("switching a note to TV keeps the time and people and drops the note text")
    func changeKindToTV() {
        let model = LogViewModel(extract: { _ in LogDraft(kind: "none", title: "") })
        let evening = Date(timeIntervalSince1970: 1_000_000)
        model.start(
            text: "Diplomat 7 and 8 with Dan",
            request: LogRequest(kind: .reflection, title: "", occurredAt: evening, people: ["Dan"], body: "Diplomat 7 and 8 with Dan"))

        model.changeKind(.tv)
        #expect(model.draft.kind == .tv)
        #expect(model.draft.body == nil)
        #expect(model.draft.occurredAt == evening)
        #expect(model.draft.people == ["Dan"])
        #expect(!model.canConfirm)

        model.draft.title = "The Diplomat"
        model.draft.episodes = [7, 8]
        #expect(model.canConfirm)

        model.changeKind(.reflection)
        #expect(model.draft.body == "Diplomat 7 and 8 with Dan")
        #expect(model.draft.episodes == nil)
        #expect(model.canConfirm)
    }
}

@Suite("Log offline queue", .serialized)
@MainActor
struct LogOfflineQueueTests {
    private nonisolated static let host = "log-offline.spark.test"

    @Test("a log the backend can't take now goes to the queue instead of failing")
    func serverErrorQueues() async throws {
        await AppStubURLProtocol.set(host: Self.host) { _ in (Data(#"{"message":"down"}"#.utf8), 503, [:]) }
        let model = LogViewModel(extract: { _ in LogDraft(kind: "none", title: "") })
        var queued: [LogRequest] = []
        model.onQueue = { queued.append($0) }
        model.start(text: "Went for a walk", request: LogRequest(kind: .reflection, title: "", body: "Went for a walk"))

        await model.confirm(using: try await makeClient())

        #expect(model.phase == .queued)
        #expect(queued.map(\.body) == ["Went for a walk"])
    }

    @Test("a request the backend rejects is shown, not queued")
    func rejectionFails() async throws {
        await AppStubURLProtocol.set(host: Self.host) { _ in (Data(#"{"message":"Write the reflection."}"#.utf8), 422, [:]) }
        let model = LogViewModel(extract: { _ in LogDraft(kind: "none", title: "") })
        var queued: [LogRequest] = []
        model.onQueue = { queued.append($0) }
        model.start(text: "x", request: LogRequest(kind: .reflection, title: "", body: "x"))

        await model.confirm(using: try await makeClient())

        #expect(model.phase == .failed("Write the reflection."))
        #expect(queued.isEmpty)
    }

    private func makeClient() async throws -> APIClient {
        let tokenStore = KeychainTokenStore(
            service: "co.cronx.sparkapp.tests.log-offline.\(UUID().uuidString)",
            account: "test",
            accessGroup: nil
        )
        try await tokenStore.store(access: "token", refresh: "refresh", expiresIn: 3_600)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStubURLProtocol.self]
        let suite = "spark.etag.log-offline.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        return APIClient(
            environment: APIEnvironment(
                baseURL: URL(string: "https://\(Self.host)/api/v1/mobile")!,
                oauthAuthorizeURL: URL(string: "https://\(Self.host)/oauth/authorize")!,
                name: "test"
            ),
            session: URLSession(configuration: configuration),
            tokenStore: tokenStore,
            etagCache: ETagCache(defaults: defaults)
        )
    }
}

@Suite("Log draft for any line")
struct LogDraftNoteTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("a line about something else becomes a note with its time and people")
    func noneIsANote() throws {
        let draft = LogDraft(kind: "none", title: "", when: "yesterday at 8pm", people: ["@dan", "Sam"])

        let request = try draft.request(text: "  Dinner at Drop Project with @dan and Sam yesterday at 8pm ", now: now)

        #expect(request.kind == .reflection)
        #expect(request.body == "Dinner at Drop Project with @dan and Sam yesterday at 8pm")
        #expect(request.people == ["Dan", "Sam"])
        #expect(request.occurredAt != nil)
    }

    @Test("the model can't pick reflection by name for a titled entry")
    func reflectionNameIsNotAKind() {
        #expect(throws: LogDraftIssue.unknownKind) {
            try LogDraft(kind: "reflection", title: "Serial").request(text: "x", now: now)
        }
    }

    @Test("episodes are read from a list or a range")
    func episodeNumbers() {
        #expect(LogPreviewFormat.episodeNumbers(from: "7, 8") == [7, 8])
        #expect(LogPreviewFormat.episodeNumbers(from: "7 and 8") == [7, 8])
        #expect(LogPreviewFormat.episodeNumbers(from: "3-5") == [3, 4, 5])
        #expect(LogPreviewFormat.episodeNumbers(from: "") == nil)
    }
}
