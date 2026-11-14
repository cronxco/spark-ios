import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("CMD return key")
@MainActor
struct CmdReturnKeyTests {
    private func makeModel(
        route: @escaping @Sendable (String) async -> CmdRouteDecision? = { _ in nil },
        structuredLog: @escaping @Sendable (String) async -> LogRequest? = { _ in nil }
    ) -> CmdViewModel {
        let defaults = UserDefaults(suiteName: "cmd-tests-\(UUID().uuidString)")!
        return CmdViewModel(
            submitter: StubCmdSubmitter(), queue: CmdQueue(defaults: defaults),
            recentStore: CmdRecentStore(defaults: defaults), route: route, structuredLog: structuredLog)
    }

    @Test("a newline typed at the end sends the line")
    func newlineSubmits() {
        let model = makeModel()
        model.input = "This is a test reflection"
        model.input = "This is a test reflection\n"
        model.inputChanged(from: "This is a test reflection")

        #expect(model.input.isEmpty)
        #expect(model.isRouting)
    }

    @Test("an empty line is not sent")
    func emptyLine() {
        let model = makeModel()
        model.input = "   "

        #expect(!model.canSubmit)
        #expect(model.submit() == nil)
        #expect(!model.isRouting)
    }

    @Test("a question opens the Flint chat without asking the model, and nothing is written or queued")
    func questionOpensFlint() async {
        let model = makeModel(route: { _ in
            Issue.record("A question should not need the model to route it")
            return .log
        })
        model.input = "How did I sleep this week?"

        await model.submit()?.value

        #expect(model.pendingAsk == "How did I sleep this week?")
        #expect(model.input.isEmpty)
        #expect(!model.isRouting)
        #expect(model.logPrefill == nil)
        #expect(model.receipt == nil)
        #expect(model.queuedCount == 0)
        #expect(model.recents.first?.intent == .ask)
    }

    @Test("a line the model takes for a request goes to Flint as typed")
    func requestGoesToFlint() async {
        let model = makeModel(route: { _ in .flint })
        model.input = "Tag yesterday's lunch as work"

        await model.submit()?.value

        #expect(model.pendingAsk == "Tag yesterday's lunch as work")
        #expect(model.pendingNavigation == nil)
        #expect(model.logPrefill == nil)
    }

    @Test("a line that names a screen goes straight there")
    func navigation() async {
        let typed = makeModel(route: { _ in
            Issue.record("\"show money\" should not need the model")
            return nil
        })
        typed.input = "show money"
        await typed.submit()?.value
        #expect(typed.pendingNavigation == .exploreMoney)
        #expect(typed.pendingAsk == nil)

        let routed = makeModel(route: { _ in .navigate(.exploreMap) })
        routed.input = "take me to where I've been"
        await routed.submit()?.value
        #expect(routed.pendingNavigation == .exploreMap)
        #expect(routed.recents.first?.intent == .command)
    }

    @Test("a line the model takes for a log opens the Log sheet on what was read")
    func logOpensSheet() async {
        let request = LogRequest(kind: .beer, title: "Guinness", people: ["Dan"])
        let model = makeModel(route: { _ in .log }, structuredLog: { _ in request })
        model.input = "2 pints of Guinness with Dan"

        await model.submit()?.value

        #expect(model.logPrefill?.request.title == "Guinness")
        #expect(model.logPrefill?.text == "2 pints of Guinness with Dan")
        #expect(model.pendingAsk == nil)
        #expect(model.recents.first?.intent == .log)
    }

    @Test("without a model a short statement is a log, read as a note, and anything unclear goes to Flint")
    func noModel() async {
        let statement = makeModel()
        statement.input = "Long walk by the river"
        await statement.submit()?.value
        #expect(statement.logPrefill?.request.kind == .reflection)
        #expect(statement.logPrefill?.request.body == "Long walk by the river")

        let unclear = makeModel()
        unclear.input = "tag the lunch"
        await unclear.submit()?.value
        #expect(unclear.logPrefill == nil)
        #expect(unclear.pendingAsk == "tag the lunch")
    }

    @Test("a slower earlier line can't open over a newer one")
    func newerLineWins() async {
        let model = makeModel(
            route: { text in
                if text.hasPrefix("First") { try? await Task.sleep(for: .milliseconds(150)) }
                return .log
            },
            structuredLog: { text in LogRequest(kind: .reflection, title: "", body: text) })

        model.input = "First thing that happened"
        let first = model.submit()
        model.input = "How did I sleep this week?"
        await model.submit()?.value
        await first?.value

        #expect(model.pendingAsk == "How did I sleep this week?")
        #expect(model.logPrefill == nil)
        #expect(!model.isRouting)
    }
}

@Suite("CMD routing rules")
struct CmdRouterTests {
    @Test("the model's answer is read forgivingly, and anything unclear is for Flint")
    func draftDecision() {
        #expect(CmdRoutingDraft(route: "log").decision == .log)
        #expect(CmdRoutingDraft(route: " Log. ").decision == .log)
        #expect(CmdRoutingDraft(route: "navigate", destination: "Money").decision == .navigate(.exploreMoney))
        #expect(CmdRoutingDraft(route: "navigate", destination: "today").decision == .navigate(.day))
        #expect(CmdRoutingDraft(route: "navigate", destination: "settings").decision == .flint)
        #expect(CmdRoutingDraft(route: "navigate").decision == .flint)
        #expect(CmdRoutingDraft(route: "flint").decision == .flint)
        #expect(CmdRoutingDraft(route: "search").decision == .flint)
    }

    @Test("only questions, @flint lines and named screens are decided without the model")
    func certain() {
        #expect(CmdRouter.certain("How did I sleep?") == .flint)
        #expect(CmdRouter.certain("what did I spend on coffee") == .flint)
        #expect(CmdRouter.certain("@flint I'm away next week") == .flint)
        #expect(CmdRouter.certain("show money") == .navigate(.exploreMoney))
        #expect(CmdRouter.certain("Go to map") == .navigate(.exploreMap))
        #expect(CmdRouter.certain("open health") == .navigate(.exploreHealth))
        #expect(CmdRouter.certain("show sleep") == nil)
        #expect(CmdRouter.certain("2 pints of Guinness") == nil)
        #expect(CmdRouter.certain("   ") == nil)
    }

    @Test("with no model, only a line the rules take for a log is one")
    func fallback() {
        #expect(CmdRouter.fallback("2 pints of Guinness") == .log)
        #expect(CmdRouter.fallback("tag the lunch") == .flint)
        #expect(CmdRouter.fallback("?coffee") == .flint)
    }
}
