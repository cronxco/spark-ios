import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("CMD return key")
@MainActor
struct CmdReturnKeyTests {
    @Test("a newline typed at the end sends the line")
    func newlineSubmits() {
        let model = CmdViewModel(
            classifier: HeuristicCmdClassifier(), submitter: StubCmdSubmitter(),
            queue: CmdQueue(), recentStore: CmdRecentStore())
        model.input = "This is a test reflection"
        model.input = "This is a test reflection\n"
        model.inputChanged(from: "This is a test reflection")

        #expect(model.input.isEmpty)
        #expect(!model.recents.isEmpty)
    }

    @Test("a question is handed to Ask Flint, not written or queued")
    func questionOpensAskFlint() {
        let defaults = UserDefaults(suiteName: "cmd-ask-tests-\(UUID().uuidString)")!
        let model = CmdViewModel(
            classifier: HeuristicCmdClassifier(), submitter: StubCmdSubmitter(),
            queue: CmdQueue(defaults: defaults), recentStore: CmdRecentStore(defaults: defaults))
        model.input = "How did I sleep this week?"

        #expect(model.effectiveIntent == .ask)
        model.submit()

        #expect(model.pendingAsk == "How did I sleep this week?")
        #expect(model.input.isEmpty)
        #expect(model.receipt == nil)
        #expect(model.queuedCount == 0)
        #expect(model.recents.first?.intent == .ask)
    }

    @Test("a log still being read does not open its sheet over Ask Flint")
    func askAbandonsALogBeingRead() async {
        let defaults = UserDefaults(suiteName: "cmd-ask-tests-\(UUID().uuidString)")!
        let model = CmdViewModel(
            classifier: HeuristicCmdClassifier(), submitter: StubCmdSubmitter(),
            queue: CmdQueue(defaults: defaults), recentStore: CmdRecentStore(defaults: defaults),
            structuredLog: { _ in
                try? await Task.sleep(for: .milliseconds(150))
                return nil
            })
        model.input = "2 pints of Guinness"
        model.submit()
        while model.receipt?.summary != "Reading" { await Task.yield() }

        model.input = "How did I sleep this week?"
        model.submit()
        #expect(model.receipt == nil)

        try? await Task.sleep(for: .milliseconds(400))
        #expect(model.logPrefill == nil)
        #expect(model.pendingAsk == "How did I sleep this week?")
    }
}
