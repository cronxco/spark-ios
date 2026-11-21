import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("Ask Flint view model")
@MainActor
struct AskFlintViewModelTests {
    @Test("a streamed answer builds up, shows its change, and is replaced by the finished message")
    func streamedAnswer() async throws {
        let change = Self.change(receipt: "r-1")
        let finished = FlintAskAnswer(
            conversationId: "c-1",
            message: FlintAskMessage(
                id: "m-1", role: .assistant, text: "Tagged [Pret](/events/e-1) as work lunch.",
                references: [FlintAskReference(kind: "event", id: "e-1", title: "Pret")], changes: [change]))
        let service = StubAskService(script: [
            .events([.conversation(id: "c-1"), .activity(label: "Searching Spark"), .delta("Tagged "), .change(change), .done(finished)]),
            .events([.delta("Yes."), .done(Self.answer("Yes.", conversation: "c-1"))]),
        ])
        let model = AskFlintViewModel(service: service)

        model.draft = "  Tag my Pret lunch as work lunch  "
        await model.send()?.value

        #expect(model.draft.isEmpty)
        #expect(model.turns.map(\.role) == [.user, .assistant])
        #expect(model.turns[0].text == "Tag my Pret lunch as work lunch")
        let answer = try #require(model.turns.last)
        #expect(answer.text == "Tagged [Pret](/events/e-1) as work lunch.")
        #expect(answer.changes == [change])
        #expect(answer.references.map(\.id) == ["e-1"])
        #expect(!answer.isStreaming)
        #expect(!model.isResponding)
        #expect(model.activity == nil)
        #expect(model.conversationId == "c-1")

        await model.ask("Did that work?")?.value

        #expect(await service.asked.map(\.conversationId) == [nil, "c-1"])
    }

    @Test("an empty or over-long draft is not sent, and nothing is sent while Flint is answering")
    func sendGuards() async {
        let service = StubAskService(script: [.events([.done(Self.answer("Hi."))])])
        let model = AskFlintViewModel(service: service)

        model.draft = "   "
        #expect(model.send() == nil)
        model.draft = String(repeating: "a", count: FlintAskEndpoint.maximumMessageLength + 1)
        #expect(model.send() == nil)

        let first = model.ask("One")
        #expect(model.ask("Two") == nil)
        await first?.value

        #expect(await service.asked.map(\.message) == ["One"])
    }

    @Test("when Spark can't be reached the question is answered on the device, and marked as such")
    func localFallback() async throws {
        let url = try #require(URL(string: "https://spark.test/flint/ask"))
        let service = StubAskService(script: [.refuse(APIError.httpStatus(503, nil, url))])
        let model = AskFlintViewModel(service: service, localAnswerer: StubLocalAnswerer(reply: "About seven hours."))

        await model.ask("How did I sleep?")?.value

        let answer = try #require(model.turns.last)
        #expect(answer.text == "About seven hours.")
        #expect(answer.source == .local)
        #expect(!answer.failed)
        #expect(model.errorMessage == nil)
    }

    @Test("a request Spark understood and refused is not answered on the device")
    func refusalIsNotAnsweredLocally() async throws {
        let url = try #require(URL(string: "https://spark.test/flint/ask"))
        let service = StubAskService(script: [.refuse(APIError.httpStatus(404, nil, url))])
        let model = AskFlintViewModel(service: service, localAnswerer: StubLocalAnswerer(reply: "Should not be used."))

        await model.ask("How did I sleep?")?.value

        let answer = try #require(model.turns.last)
        #expect(answer.failed)
        #expect(answer.source == .spark)
        // A first question names no conversation, so a 404 is the server
        // lacking Ask Flint, and the message is shown once, in the answer.
        #expect(answer.text == "Ask Flint isn't available on this Spark server yet. It needs updating.")
        #expect(model.errorMessage == nil)
    }

    @Test("a 404 while continuing a conversation says the conversation has gone")
    func missingConversation() async throws {
        let url = try #require(URL(string: "https://spark.test/flint/ask"))
        let service = StubAskService(script: [
            .events([.done(Self.answer("82.", conversation: "c-1"))]),
            .refuse(APIError.httpStatus(404, nil, url)),
        ])
        let model = AskFlintViewModel(service: service)
        await model.ask("How did I sleep?")?.value

        await model.ask("And then?")?.value

        let answer = try #require(model.turns.last)
        #expect(answer.failed)
        #expect(answer.text == "That conversation is no longer available. Start a new one.")
        #expect(model.errorMessage == nil)
    }

    @Test("the local fallback covers unreachable, unavailable and out-of-allowance, nothing else")
    func fallbackRules() throws {
        let url = try #require(URL(string: "https://spark.test/flint/ask"))
        #expect(AskFlintViewModel.allowsLocalFallback(APIError.transport(URLError(.notConnectedToInternet))))
        #expect(AskFlintViewModel.allowsLocalFallback(APIError.httpStatus(429, nil, url)))
        #expect(AskFlintViewModel.allowsLocalFallback(APIError.httpStatus(503, nil, url)))
        #expect(!AskFlintViewModel.allowsLocalFallback(APIError.httpStatus(422, nil, url)))
        #expect(!AskFlintViewModel.allowsLocalFallback(APIError.unauthorized))
    }

    @Test("a stream that fails part-way keeps what was written and its changes")
    func midStreamFailure() async throws {
        let change = Self.change(receipt: "r-1")
        let service = StubAskService(script: [
            .events([.delta("Tagged it"), .change(change), .failed(message: "Flint could not finish that answer.")]),
        ])
        let model = AskFlintViewModel(service: service)

        await model.ask("Tag it")?.value

        let answer = try #require(model.turns.last)
        #expect(answer.failed)
        #expect(answer.text == "Tagged it")
        #expect(answer.changes == [change])
        #expect(model.errorMessage == "Flint could not finish that answer.")
        #expect(!model.isResponding)
    }

    @Test("steps arrive live and are replaced by the finished message's, with its cards and follow-ups")
    func streamedSteps() async throws {
        let running = FlintAskStep(id: "s-2", glyph: "sun", label: "Reading your day", status: .running)
        let done = FlintAskStep(id: "s-2", glyph: "sun", label: "Read your day", status: .done, result: "12 events")
        let stored = [
            FlintAskStep.reasoning(id: "s-1", text: "Check the morning."),
            done,
        ]
        let finished = FlintAskAnswer(
            conversationId: "c-1",
            message: FlintAskMessage(
                id: "m-1", role: .assistant, text: "A quiet day.", steps: stored,
                followUps: ["And tomorrow?"], elapsedMs: 3100))
        let service = StubAskService(script: [
            .events([.reasoning(id: "s-1", text: "Check "), .reasoning(id: "s-1", text: "the morning."), .step(running)]),
            .events([.step(running), .step(done), .delta("A quiet day."), .done(finished)]),
        ])
        let model = AskFlintViewModel(service: service)

        await model.ask("How was today?")?.value
        let stopped = try #require(model.turns.last)
        #expect(stopped.steps.map(\.id) == ["s-1", "s-2"])
        #expect(stopped.steps[0].kind == .reasoning)
        #expect(stopped.steps[0].detail == "Check the morning.")
        #expect(stopped.steps[1].status == .failed)

        await model.ask("How was today?")?.value
        let answer = try #require(model.turns.last)
        #expect(answer.steps == stored)
        #expect(answer.followUps == ["And tomorrow?"])
        #expect(answer.elapsedMs == 3100)
        #expect(!answer.isStreaming)
    }

    @Test("a finished message with no steps keeps the streamed ones, marked done")
    func streamedStepsKept() async throws {
        let running = FlintAskStep(id: "s-1", label: "Searching payments", status: .running)
        let service = StubAskService(script: [
            .events([.step(running), .delta("None."), .done(Self.answer("None."))]),
        ])
        let model = AskFlintViewModel(service: service)

        await model.ask("Any refunds?")?.value

        let answer = try #require(model.turns.last)
        #expect(answer.steps.map(\.id) == ["s-1"])
        #expect(answer.steps[0].status == .done)
    }

    @Test("a finishing step frame without detail keeps the reasoning streamed into it")
    func stepKeepsDetail() async throws {
        let finishing = FlintAskStep(id: "s-1", kind: .reasoning, label: "Thought it through", status: .done)
        let service = StubAskService(script: [
            .events([.reasoning(id: "s-1", text: "Check Thursday."), .step(finishing), .delta("Yes."), .done(Self.answer("Yes."))]),
        ])
        let model = AskFlintViewModel(service: service)

        await model.ask("Was Thursday busy?")?.value

        let answer = try #require(model.turns.last)
        #expect(answer.steps.first?.detail == "Check Thursday.")
    }

    @Test("a failed finished message marks its running steps failed")
    func failedMessageSettlesSteps() async throws {
        let running = FlintAskStep(id: "s-1", label: "Searching", status: .running)
        let failed = FlintAskAnswer(
            conversationId: nil,
            message: FlintAskMessage(id: "m-1", role: .assistant, text: "Couldn't finish.", status: "failed"))
        let service = StubAskService(script: [.events([.step(running), .done(failed)])])
        let model = AskFlintViewModel(service: service)

        await model.ask("Any refunds?")?.value

        #expect(model.turns.last?.steps.map(\.status) == [.failed])
    }

    @Test("the hand feels an answer finish, a failure, and an undo")
    func feedback() async throws {
        let change = Self.change(receipt: "r-1")
        let service = StubAskService(script: [
            .events([.change(change), .done(Self.answer("Tagged.", changes: [change]))]),
            .events([.failed(message: "Flint could not finish that answer.")]),
        ])
        let model = AskFlintViewModel(service: service)
        #expect(model.feedback == nil)

        await model.ask("Tag it")?.value
        #expect(model.feedback?.kind == .answered)

        let answered = try #require(model.feedback)
        await model.undo(change)
        #expect(model.feedback?.kind == .undone)
        #expect(model.feedback != answered)

        await model.ask("And again")?.value
        #expect(model.feedback?.kind == .failed)
    }

    @Test("steps still running when an answer stops are marked failed")
    func settledSteps() {
        let steps = [
            FlintAskStep(id: "a", label: "Searched", status: .done),
            FlintAskStep(id: "b", label: "Reading", status: .running),
        ]
        #expect(AskFlintViewModel.settled(steps).map(\.status) == [.done, .failed])
        #expect(AskFlintViewModel.settled(steps, completed: true).map(\.status) == [.done, .done])
    }

    @Test("undo marks the change undone, and a failed undo leaves it and says so")
    func undo() async throws {
        let change = Self.change(receipt: "r-1")
        let service = StubAskService(script: [.events([.change(change), .done(Self.answer("Done.", changes: [change]))])])
        let model = AskFlintViewModel(service: service)
        await model.ask("Tag it")?.value

        await service.setUndoFails(true)
        await model.undo(change)
        #expect(model.turns.last?.changes.first?.undo.undone == false)
        #expect(model.errorMessage?.hasPrefix("Couldn't undo that.") == true)

        await service.setUndoFails(false)
        await model.undo(change)
        let undone = try #require(model.turns.last?.changes.first)
        #expect(undone.undo.undone)
        #expect(!undone.canUndo())
        #expect(model.errorMessage == nil)
        #expect(await service.undone == ["r-1", "r-1"])

        await model.undo(undone)
        #expect(await service.undone.count == 2)
    }

    @Test("an undo the server did not apply leaves the change and says so")
    func undoNotApplied() async throws {
        let change = Self.change(receipt: "r-1")
        let service = StubAskService(script: [.events([.change(change), .done(Self.answer("Done.", changes: [change]))])])
        let model = AskFlintViewModel(service: service)
        await model.ask("Tag it")?.value

        await service.setUndoApplies(false)
        await model.undo(change)

        let kept = try #require(model.turns.last?.changes.first)
        #expect(!kept.undo.undone)
        #expect(kept.canUndo())
        #expect(model.errorMessage == "Couldn't undo that. Try again.")
    }

    @Test("nothing can be asked while a past conversation loads, and a load that was left is dropped")
    func staleHistoryLoad() async {
        let service = StubAskService(script: [])
        await service.setHistory([FlintAskMessage(id: "m-1", role: .user, text: "Old question")])
        await service.setHistoryDelay(.milliseconds(150))
        let model = AskFlintViewModel(service: service)

        let load = Task { await model.open(FlintAskConversation(id: "c-old", title: "Old")) }
        while !model.isLoadingConversation { await Task.yield() }

        model.draft = "A question"
        #expect(!model.canSend)
        #expect(model.send() == nil)
        #expect(model.ask("A question") == nil)

        model.startNewConversation()
        #expect(!model.isLoadingConversation)
        await load.value

        #expect(model.turns.isEmpty)
        #expect(model.conversationId == nil)
        #expect(!model.isLoadingConversation)
        #expect(await service.asked.isEmpty)
    }

    @Test("opening a past conversation loads its turns and continues that thread")
    func openConversation() async {
        let service = StubAskService(script: [.events([.done(Self.answer("Still 82.", conversation: "c-9"))])])
        await service.setHistory([
            FlintAskMessage(id: "m-1", role: .user, text: "How did I sleep?"),
            FlintAskMessage(id: "m-2", role: .assistant, text: "Your sleep score was 82."),
        ])
        let model = AskFlintViewModel(service: service)

        await model.open(FlintAskConversation(id: "c-9", title: "How did I sleep?"))

        #expect(model.turns.map(\.text) == ["How did I sleep?", "Your sleep score was 82."])
        #expect(model.conversationId == "c-9")

        await model.ask("And now?")?.value
        #expect(await service.asked.last?.conversationId == "c-9")

        model.startNewConversation()
        #expect(model.turns.isEmpty)
        #expect(model.conversationId == nil)
    }

    // MARK: - Fixtures

    private static func change(receipt: String) -> FlintAskChange {
        FlintAskChange(
            receiptId: receipt, operation: "tag", kind: "event", entityId: "e-1", title: "Pret",
            summary: "Tagged work lunch",
            undo: .init(available: true, expiresAt: Date.now.addingTimeInterval(900)))
    }

    private static func answer(
        _ text: String, conversation: String? = nil, changes: [FlintAskChange] = []
    ) -> FlintAskAnswer {
        FlintAskAnswer(
            conversationId: conversation,
            message: FlintAskMessage(id: UUID().uuidString, role: .assistant, text: text, changes: changes))
    }
}

/// Plays back one scripted response per question, in order.
private actor StubAskService: AskFlintServing {
    enum Response: Sendable {
        case events([FlintAskStreamEvent])
        case refuse(APIError)
    }

    struct Asked: Sendable {
        let message: String
        let conversationId: String?
    }

    private var script: [Response]
    private var undoFails = false
    private var undoApplies = true
    private var historyDelay: Duration?
    private var history: [FlintAskMessage] = []
    private(set) var asked: [Asked] = []
    private(set) var undone: [String] = []

    init(script: [Response]) {
        self.script = script
    }

    func setUndoFails(_ fails: Bool) { undoFails = fails }
    func setUndoApplies(_ applies: Bool) { undoApplies = applies }
    func setHistoryDelay(_ delay: Duration?) { historyDelay = delay }
    func setHistory(_ messages: [FlintAskMessage]) { history = messages }

    func stream(message: String, conversationId: String?) async throws -> AsyncThrowingStream<FlintAskStreamEvent, Error> {
        asked.append(Asked(message: message, conversationId: conversationId))
        guard !script.isEmpty else { throw APIError.noData }

        switch script.removeFirst() {
        case .refuse(let error):
            throw error
        case .events(let events):
            return AsyncThrowingStream { continuation in
                for event in events { continuation.yield(event) }
                continuation.finish()
            }
        }
    }

    func undo(receiptId: String) async throws -> Bool {
        undone.append(receiptId)
        if undoFails { throw APIError.noData }
        return undoApplies
    }

    func conversations(search: String?) async throws -> [FlintAskConversation] { [] }
    func messages(conversationId: String) async throws -> [FlintAskMessage] {
        if let historyDelay { try? await Task.sleep(for: historyDelay) }
        return history
    }
    func delete(conversationId: String) async throws {}
}

private struct StubLocalAnswerer: AskFlintLocalAnswering {
    let reply: String?

    func answer(question: String) async -> String? { reply }
}
