import Foundation
import Testing
@testable import SparkKit

@Suite("Ask Flint")
struct FlintAskTests {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Endpoints

    @Test("asking posts the message and conversation without streaming")
    func askRequestShape() throws {
        let endpoint = FlintAskEndpoint.ask(message: "How did I sleep?", conversationId: "c-1")

        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/flint/ask")
        let body = try #require(endpoint.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["message"] as? String == "How did I sleep?")
        #expect(json["conversation_id"] as? String == "c-1")
        #expect(json["stream"] as? Bool == false)
        #expect(json["read_only"] == nil)
    }

    @Test("a read-only ask says so, for callers that can't show an Undo")
    func readOnlyRequestShape() throws {
        let endpoint = FlintAskEndpoint.ask(message: "How did I sleep?", readOnly: true)

        let body = try #require(endpoint.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["read_only"] as? Bool == true)
        #expect(json["stream"] as? Bool == false)
    }

    @Test("questions and answers are kept out of captured telemetry bodies")
    func telemetryOmitsConversationBodies() {
        #expect(APITelemetryRedactor.omitsBody(forPath: "/flint/ask"))
        #expect(APITelemetryRedactor.omitsBody(forPath: "/flint/ask/conversations"))
        #expect(APITelemetryRedactor.omitsBody(forPath: "/flint/ask/conversations/c-1"))
        #expect(APITelemetryRedactor.omitsBody(forPath: "/flint/notes/n-1"))
        #expect(!APITelemetryRedactor.omitsBody(forPath: "/flint/asking"))
        #expect(!APITelemetryRedactor.omitsBody(forPath: "/feed"))
    }

    @Test("a streamed ask sets the stream flag and omits an absent conversation")
    func streamingRequestShape() throws {
        let endpoint = FlintAskEndpoint.askStreaming(message: "Tag it")

        let body = try #require(endpoint.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["stream"] as? Bool == true)
        #expect(json["conversation_id"] == nil)
    }

    @Test("history endpoints carry the limit and cursor")
    func historyEndpoints() {
        let list = FlintAskEndpoint.conversations(cursor: "abc")
        #expect(list.path == "/flint/ask/conversations")
        #expect(list.query.contains(URLQueryItem(name: "cursor", value: "abc")))

        let messages = FlintAskEndpoint.messages(conversationId: "c-1")
        #expect(messages.method == .get)
        #expect(messages.path == "/flint/ask/conversations/c-1")
        #expect(messages.query == [URLQueryItem(name: "limit", value: "30")])

        let delete = FlintAskEndpoint.deleteConversation(id: "c-1")
        #expect(delete.method == .delete)
        #expect(delete.path == "/flint/ask/conversations/c-1")
    }

    // MARK: - Decoding

    @Test("an answer decodes with its references and changes")
    func answerDecodes() throws {
        let json = """
        {
          "contract_version": 1,
          "conversation_id": "01a1ca8b-9e5e-7239-b47a-ecb00947ad5c",
          "message": {
            "id": "01a1ca8b-9e6b-72bc-9c24-660bfdf94d97",
            "role": "assistant",
            "text": "Tagged [Pret](/events/e-1) as work lunch.",
            "references": [{"kind": "event", "id": "e-1", "title": "Card payment to Pret A Manger"}],
            "changes": [{
              "receipt_id": "r-1", "operation": "tag", "kind": "event", "id": "e-1",
              "title": "Card payment to Pret A Manger", "summary": "Tagged work lunch",
              "undo": {"available": true, "expires_at": "2026-11-11T12:33:30+00:00", "undone": false}
            }],
            "status": "completed",
            "created_at": "2026-11-11T12:18:30+00:00"
          }
        }
        """

        let answer = try decoder.decode(FlintAskAnswer.self, from: Data(json.utf8))

        #expect(answer.conversationId == "01a1ca8b-9e5e-7239-b47a-ecb00947ad5c")
        #expect(answer.message.role == .assistant)
        #expect(answer.message.references.first?.deepLink == .event(id: "e-1"))
        let change = try #require(answer.message.changes.first)
        #expect(change.receiptId == "r-1")
        #expect(change.entityId == "e-1")
        #expect(change.id == "r-1")
        #expect(change.undo.expiresAt != nil)
        #expect(answer.message.createdAt != nil)
    }

    @Test("a user message decodes without references or changes")
    func sparseMessageDecodes() throws {
        let json = #"{"id": "m-1", "role": "user", "text": "Hello"}"#

        let message = try decoder.decode(FlintAskMessage.self, from: Data(json.utf8))

        #expect(message.role == .user)
        #expect(message.references.isEmpty)
        #expect(message.changes.isEmpty)
        #expect(message.status == "completed")
    }

    // MARK: - Undo

    @Test("undo is offered only while the receipt allows it and has not expired")
    func undoAvailability() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func change(available: Bool, expiresIn: TimeInterval?, undone: Bool = false, receipt: String? = "r-1") -> FlintAskChange {
            FlintAskChange(
                receiptId: receipt, operation: "tag", kind: "event", entityId: "e-1", title: "Pret", summary: "Tagged",
                undo: .init(available: available, expiresAt: expiresIn.map { now.addingTimeInterval($0) }, undone: undone)
            )
        }

        #expect(change(available: true, expiresIn: 60).canUndo(at: now))
        #expect(change(available: true, expiresIn: nil).canUndo(at: now))
        #expect(!change(available: true, expiresIn: -1).canUndo(at: now))
        #expect(!change(available: false, expiresIn: 60).canUndo(at: now))
        #expect(!change(available: true, expiresIn: 60, undone: true).canUndo(at: now))
        #expect(!change(available: true, expiresIn: 60, receipt: nil).canUndo(at: now))

        let undone = change(available: true, expiresIn: 60).markedUndone()
        #expect(undone.undo.undone)
        #expect(!undone.canUndo(at: now))
    }

    // MARK: - Server-sent events

    @Test("events are assembled from event and data lines, with or without blank lines")
    func parserAssemblesEvents() {
        var parser = ServerSentEventParser()
        var events: [ServerSentEvent] = []
        let lines = [
            "event: conversation", #"data: {"conversation_id":"c-1"}"#, "",
            ": keep-alive",
            "event: delta", #"data: {"text":"Hi"}"#,
            "event: delta", #"data: {"text":" there"}"#, "",
            #"data: {"orphan":true}"#,
            "retry: 3000",
        ]
        for line in lines {
            if let event = parser.consume(line) { events.append(event) }
        }

        #expect(events.map(\.name) == ["conversation", "delta", "delta", "message"])
        #expect(events[1].data == #"{"text":"Hi"}"#)
    }

    @Test("a data line keeps colons in its payload and tolerates no space")
    func parserKeepsPayload() {
        var parser = ServerSentEventParser()
        _ = parser.consume("event:delta")

        let event = parser.consume(#"data:{"text":"at 12:30"}"#)

        #expect(event == ServerSentEvent(name: "delta", data: #"{"text":"at 12:30"}"#))
    }

    @Test("stream frames decode to typed events and unknown frames are skipped")
    func streamEventsDecode() {
        #expect(FlintAskStreamEvent.decode(.init(name: "conversation", data: #"{"contract_version":1,"conversation_id":"c-1"}"#)) == .conversation(id: "c-1"))
        #expect(FlintAskStreamEvent.decode(.init(name: "delta", data: #"{"text":"Hi"}"#)) == .delta("Hi"))
        #expect(FlintAskStreamEvent.decode(.init(name: "activity", data: #"{"tool":"search-events","label":"Searching Spark"}"#)) == .activity(label: "Searching Spark"))
        #expect(FlintAskStreamEvent.decode(.init(name: "error", data: #"{"message":"Nope"}"#)) == .failed(message: "Nope"))
        #expect(FlintAskStreamEvent.decode(.init(name: "from-the-future", data: "{}")) == nil)
        #expect(FlintAskStreamEvent.decode(.init(name: "delta", data: "not json")) == nil)

        let change = FlintAskStreamEvent.decode(.init(
            name: "change",
            data: #"{"receipt_id":"r-1","operation":"delete","kind":"event","id":"e-1","title":"Pret","summary":"Moved to the bin","undo":{"available":true,"expires_at":"2026-11-11T12:33:30+00:00","undone":false}}"#
        ))
        guard case .change(let decoded)? = change else {
            Issue.record("change frame did not decode")
            return
        }
        #expect(decoded.operation == "delete")

        let done = FlintAskStreamEvent.decode(.init(
            name: "done",
            data: #"{"conversation_id":"c-1","message":{"id":"m-2","role":"assistant","text":"Done.","references":[],"changes":[],"status":"completed","created_at":"2026-11-11T12:18:30+00:00"}}"#
        ))
        guard case .done(let answer)? = done else {
            Issue.record("done frame did not decode")
            return
        }
        #expect(answer.message.text == "Done.")
    }

    // MARK: - Text

    @Test("record links become absolute deep links and other links are left alone")
    func linkification() throws {
        let text = "See [Pret](/events/e-1), [Monzo](/objects/o-1) and [the docs](https://example.com/events/x)."

        let linked = FlintAskText.linkified(text)

        #expect(linked == "See [Pret](https://spark.cronx.co/events/e-1), [Monzo](https://spark.cronx.co/objects/o-1) and [the docs](https://example.com/events/x).")
        let url = try #require(URL(string: "https://spark.cronx.co/events/e-1"))
        #expect(DeepLink.parse(url) == .event(id: "e-1"))
    }

    @Test("spoken text drops markup and stops at a sentence")
    func spokenText() {
        let markdown = """
        ## Sleep
        - You slept **7 hours 49 minutes**, see [last night](/events/e-1).
        - Score was `82`.
        """

        #expect(FlintAskText.spoken(markdown) == "Sleep You slept 7 hours 49 minutes, see last night. Score was 82.")

        let long = String(repeating: "This is a sentence. ", count: 40)
        let spoken = FlintAskText.spoken(long, limit: 100)
        #expect(spoken.count <= 100)
        #expect(spoken.hasSuffix("."))
    }
}
