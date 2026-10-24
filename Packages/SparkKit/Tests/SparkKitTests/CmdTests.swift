import Foundation
import Testing

@testable import SparkKit

@Suite("CMD")
struct CmdTests {
    @Test("prefixes force an intent")
    func prefixes() {
        #expect(HeuristicCmdClassifier.classifySync("/sync Monzo")?.intent == .command)
        #expect(HeuristicCmdClassifier.classifySync("/sync Monzo")?.text == "sync Monzo")
        #expect(HeuristicCmdClassifier.classifySync("?dentist")?.intent == .search)
        #expect(HeuristicCmdClassifier.classifySync("?dentist")?.isForced == true)
    }

    @Test("@flint is a note for Flint, not a person called flinton")
    func flintHandle() {
        let note = HeuristicCmdClassifier.classifySync("@flint stop asking about sleep")
        #expect(note?.intent == .flintNote)
        #expect(note?.text == "stop asking about sleep")
        #expect(HeuristicCmdClassifier.classifySync("coffee with @flinton")?.intent == .log)
    }

    @Test("short lines log, long or ambiguous lines ask")
    func confidence() {
        #expect(HeuristicCmdClassifier.classifySync("2 pints of Guinness")?.needsAsk == false)
        #expect(HeuristicCmdClassifier.classifySync("run 5k")?.needsAsk == true)
        let long = Array(repeating: "word", count: 20).joined(separator: " ")
        #expect(HeuristicCmdClassifier.classifySync(long)?.needsAsk == true)
        #expect(HeuristicCmdClassifier.classifySync("   ") == nil)
    }

    @Test("queue keeps order and stops at the first retry")
    func queueFlush() async {
        let defaults = UserDefaults(suiteName: "cmd-tests-\(UUID().uuidString)")!
        let queue = CmdQueue(defaults: defaults)
        let a = CmdEntry(intent: .log, text: "a", classifiedAs: .log)
        let b = CmdEntry(intent: .log, text: "b", classifiedAs: .log)
        queue.enqueue(a)
        queue.enqueue(a)
        queue.enqueue(b)
        #expect(queue.load().count == 2)

        struct Offline: CmdSubmitting {
            func submit(_ entry: CmdEntry) async -> CmdSubmissionResult { .retry }
            func undo(token: String) async -> Bool { false }
        }
        #expect(await queue.flush(using: Offline()).isEmpty)
        #expect(queue.load().count == 2)

        let sent = await queue.flush(using: StubCmdSubmitter())
        #expect(sent.map(\.0.text) == ["a", "b"])
        #expect(queue.load().isEmpty)
    }

    @Test("recents dedupe, cap and expire")
    func recents() {
        let defaults = UserDefaults(suiteName: "cmd-tests-\(UUID().uuidString)")!
        let store = CmdRecentStore(defaults: defaults)
        store.record(text: "a", intent: .log)
        store.record(text: "b", intent: .log)
        #expect(store.record(text: "a", intent: .log).map(\.text) == ["a", "b"])
        let later = CmdRecentStore(defaults: defaults, now: { Date().addingTimeInterval(CmdRecentStore.maxAge + 60) })
        #expect(later.load().isEmpty)
    }

    @Test("wire names round-trip")
    func wireNames() {
        #expect(ServerCmdClassifier.wire(.flintNote) == "flint_note")
        #expect(ServerCmdClassifier.intent(from: "flint_note") == .flintNote)
        #expect(ServerCmdClassifier.intent(from: "unsure") == nil)
    }

    @Test("commit request encodes the contract keys")
    func commitEncoding() throws {
        let request = QuickLogIntentsEndpoint.CommitRequest(
            idempotencyKey: "k", text: "t", intent: "flint_note", suggestedIntent: nil,
            confidence: 1, occurredAt: Date(timeIntervalSince1970: 0))
        let body = try #require(QuickLogIntentsEndpoint.commit(request).body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["idempotency_key"] as? String == "k")
        #expect(json["occurred_at"] as? String == "1970-01-01T00:00:00Z")
    }

    @Test("registry actions decode and report whether they need input")
    func actionDecoding() throws {
        let json = Data(
            #"{"data":[{"id":"sync-all","title":"Sync all","kind":"safe","confirm":"none","target":{}},{"id":"add-tag","title":"Tag event","kind":"data","confirm":"undo","target":{"event_id":{"type":"uuid"}}}]}"#
                .utf8)
        let list = try JSONDecoder().decode(CmdActionsEndpoint.ListResponse.self, from: json)
        #expect(list.data[0].runsWithoutInput)
        #expect(!list.data[1].runsWithoutInput)
    }

    @Test("reflection request encodes kind, body and key")
    func reflectionEncoding() throws {
        let request = LogEndpoint.ReflectionRequest(
            idempotencyKey: "k", body: "coffee with Dan", occurredAt: Date(timeIntervalSince1970: 0))
        let body = try #require(LogEndpoint.reflection(request).body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["kind"] as? String == "reflection")
        #expect(json["body"] as? String == "coffee with Dan")
        #expect(json["idempotency_key"] as? String == "k")
    }

    @Test("reflection request carries matched people by id and new people by name")
    func reflectionPeople() throws {
        let request = LogEndpoint.ReflectionRequest(
            idempotencyKey: "k", body: "coffee with @dan", occurredAt: Date(timeIntervalSince1970: 0),
            personIds: ["p1"], newPeople: ["Sam"])
        let body = try #require(LogEndpoint.reflection(request).body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["with_ids"] as? [String] == ["p1"])
        #expect(json["with"] as? [String] == ["Sam"])
    }

    @Test("classify response decodes people and tolerates their absence")
    func classifyPeople() throws {
        let with = Data(
            #"{"intent":"log","confidence":0.9,"needs_choice":false,"text":"x","people":[{"name":"dan","state":"likely","matches":[{"id":"p1","name":"Daniel"}]}]}"#
                .utf8)
        let decoded = try JSONDecoder().decode(QuickLogIntentsEndpoint.ClassifyResponse.self, from: with)
        let mentions = ServerCmdClassifier.mentions(from: decoded.people)
        #expect(mentions == [CmdMention(name: "dan", state: .likely, matches: [.init(id: "p1", name: "Daniel")])])
        let without = Data(#"{"intent":"log","confidence":0.9,"needs_choice":false,"text":"x"}"#.utf8)
        #expect(try JSONDecoder().decode(QuickLogIntentsEndpoint.ClassifyResponse.self, from: without).people.isEmpty)
    }

    @Test("mentions link likely people, create new ones and wait on ambiguous ones")
    func personLinks() {
        let dan = CmdMention(name: "dan", state: .likely, matches: [.init(id: "p1", name: "Daniel")])
        let sam = CmdMention(name: "sam", state: .new, matches: [])
        let al = CmdMention(name: "al", state: .ambiguous, matches: [.init(id: "a1", name: "Alan"), .init(id: "a2", name: "Alex")])
        #expect(CmdPersonLinks.resolve([dan, sam], picks: [:]) == CmdPersonLinks(ids: ["p1"], newNames: ["Sam"]))
        #expect(CmdPersonLinks.resolve([dan, al], picks: [:]) == nil)
        #expect(CmdPersonLinks.unresolved([dan, al], picks: [:]) == al)
        #expect(CmdPersonLinks.resolve([al], picks: ["al": .person(id: "a2")]) == CmdPersonLinks(ids: ["a2"]))
        #expect(CmdPersonLinks.resolve([al], picks: ["al": .createNew]) == CmdPersonLinks(newNames: ["Al"]))
    }

    @Test("override is detected")
    func override() {
        #expect(CmdEntry(intent: .search, text: "x", classifiedAs: .log).wasOverridden)
        #expect(!CmdEntry(intent: .log, text: "x", classifiedAs: .log).wasOverridden)
    }
}
