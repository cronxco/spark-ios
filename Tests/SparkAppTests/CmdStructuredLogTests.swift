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

    @Test("a line with no flow of its own is saved as before")
    func plainLineFallsBack() async {
        let submitter = RecordingSubmitter()
        let model = makeModel(submitter: submitter) { _ in nil }

        model.input = "Went for a walk by the river"
        model.submit()
        await settle(model) { !submitter.submitted.isEmpty }

        #expect(model.logPrefill == nil)
        #expect(submitter.submitted.map(\.intent) == [.log])
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
}
