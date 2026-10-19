import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("Log draft")
struct LogDraftTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("a beer keeps its serving and quantity")
    func beerDraft() throws {
        let draft = LogDraft(kind: "beer", title: "  Verdant Nebulous Sky ", quantity: 1, serving: "can")

        let request = try draft.request(now: now, idempotencyKey: "k")

        #expect(request.kind == .beer)
        #expect(request.title == "Verdant Nebulous Sky")
        #expect(request.quantity == 1)
        #expect(request.serving == .can)
        #expect(request.idempotencyKey == "k")
        #expect(request.occurredAt == nil)
        #expect(request.episodes == nil)
    }

    @Test("minutes ago becomes an earlier time")
    func minutesAgo() throws {
        let draft = LogDraft(kind: "wine", title: "Cafe François Rouge", quantity: 0.5, unit: "bottle", minutesAgo: 90)

        let request = try draft.request(now: now)

        #expect(request.occurredAt == now.addingTimeInterval(-5_400))
        #expect(request.quantity == 0.5)
        #expect(request.unit == "bottle")
        #expect(request.serving == nil)
    }

    @Test("a serving is only kept for beer")
    func servingOnlyForBeer() throws {
        let request = try LogDraft(kind: "wine", title: "Rioja", serving: "bottle").request(now: now)

        #expect(request.serving == nil)
    }

    @Test("TV episodes are sorted, deduplicated and kept in range")
    func televisionEpisodes() throws {
        let draft = LogDraft(kind: "tv", title: "The Diplomat", season: 3, episodes: [2, 1, 2, 0, 1_000])

        let request = try draft.request(now: now)

        #expect(request.episodes == [1, 2])
        #expect(request.season == 3)
    }

    @Test("a season outside the backend range is dropped")
    func seasonOutOfRange() throws {
        let request = try LogDraft(kind: "tv", title: "The Diplomat", season: 0, episodes: [1]).request(now: now)

        #expect(request.season == nil)
    }

    @Test("TV without episodes asks for them")
    func televisionNeedsEpisodes() {
        #expect(throws: LogDraftIssue.missingEpisodes) {
            try LogDraft(kind: "tv", title: "The Diplomat", episodes: []).request(now: now)
        }
        #expect(throws: LogDraftIssue.missingEpisodes) {
            try LogDraft(kind: "tv", title: "The Diplomat").request(now: now)
        }
    }

    @Test("the kind is read however the model spells it")
    func kindSpelling() throws {
        for spelling in ["boardGame", "board game", "Board_Game"] {
            #expect(try LogDraft(kind: spelling, title: "Catan").request(now: now).kind == .boardGame)
        }
        #expect(throws: LogDraftIssue.unknownKind) {
            try LogDraft(kind: "podcast", title: "Serial").request(now: now)
        }
    }

    @Test("a blank title is rejected")
    func blankTitle() {
        #expect(throws: LogDraftIssue.missingTitle) {
            try LogDraft(kind: "wine", title: "   ").request(now: now)
        }
    }

    @Test("values the backend would reject are dropped, not sent")
    func outOfRangeValuesDropped() throws {
        let request = try LogDraft(kind: "beer", title: "IPA", quantity: 0, volumeML: 5).request(now: now)

        #expect(request.quantity == nil)
        #expect(request.volumeML == nil)
    }
}

@Suite("Log when parser")
struct LogWhenParserTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// Monday 19 October 2026, 15:00 in London.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 15))! }

    /// Day, hour and minute of the date read from the phrase.
    private func parts(_ phrase: String) -> [Int]? {
        LogWhenParser.date(from: phrase, now: now, calendar: calendar).map {
            [calendar.component(.day, from: $0), calendar.component(.hour, from: $0), calendar.component(.minute, from: $0)]
        }
    }

    @Test("yesterday at a time")
    func yesterdayAtEight() {
        #expect(parts("yesterday at 8pm") == [18, 20, 0])
    }

    @Test("last night is yesterday evening")
    func lastNight() {
        #expect(parts("last night") == [18, 21, 0])
    }

    @Test("a bare hour takes the latest time that has already passed")
    func bareHour() {
        #expect(parts("at 2") == [19, 14, 0])
        #expect(parts("at 8") == [19, 8, 0])
    }

    @Test("a weekday is the most recent one, with a part of the day")
    func weekdayLunch() {
        #expect(parts("Saturday lunch") == [17, 13, 0])
    }

    @Test("times ago count back from now")
    func agoPhrases() {
        #expect(LogWhenParser.date(from: "40 minutes ago", now: now, calendar: calendar) == now.addingTimeInterval(-2_400))
        #expect(LogWhenParser.date(from: "an hour ago", now: now, calendar: calendar) == now.addingTimeInterval(-3_600))
        #expect(LogWhenParser.date(from: "half an hour ago", now: now, calendar: calendar) == now.addingTimeInterval(-1_800))
    }

    @Test("words that say nothing about time give nothing")
    func noTime() {
        #expect(LogWhenParser.date(from: "", now: now, calendar: calendar) == nil)
        #expect(LogWhenParser.date(from: "just now", now: now, calendar: calendar) == nil)
    }

    @Test("a time later today is held at now")
    func futureIsClamped() throws {
        let date = try #require(LogWhenParser.date(from: "today at 9pm", now: now, calendar: calendar))

        #expect(date == now)
    }
}

@Suite("Log preview format")
struct LogPreviewFormatTests {
    @Test("amounts read naturally")
    func amounts() {
        #expect(LogPreviewFormat.amount(LogRequest(kind: .wine, title: "Rioja", quantity: 0.5, unit: "bottle")) == "½ bottle")
        #expect(LogPreviewFormat.amount(LogRequest(kind: .beer, title: "IPA", quantity: 1, serving: .can)) == "1 can")
        #expect(LogPreviewFormat.amount(LogRequest(kind: .beer, title: "IPA", quantity: 1, serving: .draft, volumeML: 568)) == "1 draft · 568 ml")
        #expect(LogPreviewFormat.amount(LogRequest(kind: .wine, title: "Rioja")) == nil)
    }

    @Test("consecutive episodes become ranges")
    func episodeRanges() {
        #expect(LogPreviewFormat.episodes([1, 2]) == "E1–2")
        #expect(LogPreviewFormat.episodes([5, 1, 4, 2]) == "E1–2, E4–5")
        #expect(LogPreviewFormat.episodes([3]) == "E3")
    }

    @Test("fractions use vulgar halves and quarters")
    func fractions() {
        #expect(LogPreviewFormat.fraction(1.5) == "1½")
        #expect(LogPreviewFormat.fraction(2) == "2")
        #expect(LogPreviewFormat.fraction(0.25) == "¼")
    }

    @Test("no time means now")
    func noTime() {
        #expect(LogPreviewFormat.when(nil) == "Now")
    }
}

@Suite("Log view model", .serialized)
@MainActor
struct LogViewModelTests {
    private nonisolated static let host = "log.spark.test"

    private nonisolated static func diplomat() -> LogDraft {
        LogDraft(kind: "tv", title: "The Diplomat", episodes: [1, 2])
    }

    @Test("a season question is answered and the request is resent with that season")
    func answersSeasonQuestion() async throws {
        actor Attempts {
            var count = 0
            func next() -> Int { count += 1; return count }
        }
        let attempts = Attempts()
        await AppStubURLProtocol.set(host: Self.host) { _ in
            if await attempts.next() == 1 {
                return (Data(Self.seasonQuestion.utf8), 200, [:])
            }
            return (Data(Self.logged.utf8), 201, [:])
        }
        let model = LogViewModel(extract: { _ in Self.diplomat() })
        let client = try await makeClient()
        model.updateText("Just watched episodes 1 and 2 of The Diplomat")

        await model.submit(using: client)
        await model.confirm(using: client)
        guard case .question(let question) = model.phase else {
            Issue.record("Expected a season question, got \(model.phase)")
            return
        }
        #expect(question.field == .season)

        await model.answer(try #require(question.options.first), using: client)

        guard case .logged(let outcome) = model.phase else {
            Issue.record("Expected the entry to be logged, got \(model.phase)")
            return
        }
        #expect(outcome.events.map(\.id) == ["e1", "e2"])

        let requests = await AppStubURLProtocol.recorded(host: Self.host)
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.httpMethod == "POST" && $0.url?.path.hasSuffix("/log") == true })
    }

    @Test("reading shows a preview and sends nothing until it is confirmed")
    func previewBeforeLogging() async throws {
        await AppStubURLProtocol.set(host: Self.host) { _ in (Data(Self.logged.utf8), 201, [:]) }
        let model = LogViewModel(extract: { _ in LogDraft(kind: "wine", title: "Rioja", quantity: 0.5, unit: "bottle", people: ["Dan", "dan", " Sam "]) })
        let client = try await makeClient()
        model.updateText("Half a bottle of Rioja with Dan and Sam")

        await model.submit(using: client)

        #expect(model.phase == .preview)
        #expect(model.draft.title == "Rioja")
        #expect(model.draft.people == ["Dan", "Sam"])
        #expect(await AppStubURLProtocol.recorded(host: Self.host).isEmpty)

        model.draft.title = "Rioja Reserva"
        model.removePerson("Dan")
        model.addPerson("Alex")
        model.addPerson("alex")
        #expect(model.draft.people == ["Sam", "Alex"])

        await model.confirm(using: client)

        let requests = await AppStubURLProtocol.recorded(host: Self.host)
        #expect(requests.count == 1)
        let body = try #require(requests.first?.httpBody)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["title"] as? String == "Rioja Reserva")
        #expect(object["with"] as? [String] == ["Sam", "Alex"])
    }

    @Test("a partial name waits for a choice, then logs under the person picked")
    func partialNameIsResolvedBeforeLogging() async throws {
        let peoplePreview = """
        {"status": "preview", "match": null, "people": [
          {"name": "Dan", "state": "likely", "matches": [{"id": "p1", "name": "Daniel Smith"}]},
          {"name": "daniel", "state": "existing", "matches": [{"id": "p2", "name": "Daniel"}]},
          {"name": "Priya", "state": "new", "matches": []}
        ]}
        """
        await AppStubURLProtocol.set(host: Self.host) { request in
            let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            return body.contains("\"dry_run\":true") ? (Data(peoplePreview.utf8), 200, [:]) : (Data(Self.logged.utf8), 201, [:])
        }
        let model = LogViewModel(extract: { _ in LogDraft(kind: "wine", title: "Rioja", people: ["Dan", "daniel", "Priya"]) })
        let client = try await makeClient()
        model.updateText("Rioja with Dan, Daniel and Priya")
        await model.submit(using: client)

        await model.refreshPeople(using: client)

        #expect(model.draft.people == ["Dan", "Daniel", "Priya"])
        #expect(model.hasUnresolvedPeople)
        #expect(model.isUnresolved("Dan"))
        #expect(!model.isUnresolved("Priya"))

        await model.confirm(using: client)
        #expect(model.phase == .preview)

        model.resolvePerson("Dan", as: LogPersonCheck.Match(id: "p1", name: "Daniel Smith"))
        #expect(model.draft.people == ["Daniel Smith", "Daniel", "Priya"])
        #expect(!model.hasUnresolvedPeople)
    }

    @Test("keeping a similar name as new settles it")
    func keepingNewSettlesTheName() async throws {
        let peoplePreview = """
        {"status": "preview", "match": null, "people": [
          {"name": "Sam", "state": "ambiguous", "matches": [{"id": "p1", "name": "Sam Jones"}, {"id": "p2", "name": "Samantha"}]}
        ]}
        """
        await AppStubURLProtocol.set(host: Self.host) { _ in (Data(peoplePreview.utf8), 200, [:]) }
        let model = LogViewModel(extract: { _ in LogDraft(kind: "wine", title: "Rioja", people: ["Sam"]) })
        let client = try await makeClient()
        model.updateText("Rioja with Sam")
        await model.submit(using: client)
        await model.refreshPeople(using: client)
        #expect(model.hasUnresolvedPeople)

        model.keepNewPerson("Sam")

        #expect(!model.hasUnresolvedPeople)
        #expect(model.isNewPerson("sam"))
        #expect(model.draft.people == ["Sam"])
    }

    @Test("a dry run fills the match, and a chosen runner-up is sent when logging")
    func dryRunThenChooseMatch() async throws {
        await AppStubURLProtocol.set(host: Self.host) { request in
            let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            if body.contains("\"dry_run\":true") {
                return (Data(Self.winePreview.utf8), 200, [:])
            }
            return (Data(Self.logged.utf8), 201, [:])
        }
        let model = LogViewModel(extract: { _ in LogDraft(kind: "wine", title: "Raquillet", rating: 4) })
        let client = try await makeClient()
        model.updateText("Raquillet, 4 stars")
        await model.submit(using: client)

        await model.refreshMatch(using: client)

        guard case .loaded(let match?) = model.matchState else {
            Issue.record("Expected a match, got \(model.matchState)")
            return
        }
        #expect(match.best?.title == "Raquillet Mercurey")
        let other = try #require(match.candidates.first)

        model.chooseMatch(other)
        await model.confirm(using: client)

        let requests = await AppStubURLProtocol.recorded(host: Self.host)
        #expect(requests.count == 2)
        let dryRun = try #require(requests.first?.httpBody)
        let log = try #require(requests.last?.httpBody)
        #expect((try JSONSerialization.jsonObject(with: dryRun) as? [String: Any])?["dry_run"] as? Bool == true)
        let sent = try #require(try JSONSerialization.jsonObject(with: log) as? [String: Any])
        #expect(sent["dry_run"] == nil)
        #expect(sent["match_url"] as? String == "https://www.vivino.com/en/y/w/2")
        #expect(sent["rating"] as? Double == 4)
    }

    @Test("cinema and board games have nothing to look up")
    func nothingToLookUp() async throws {
        await AppStubURLProtocol.set(host: Self.host) { _ in (Data(), 500, [:]) }
        let model = LogViewModel(extract: { _ in LogDraft(kind: "cinema", title: "Dune") })
        let client = try await makeClient()
        model.updateText("Dune at the cinema")
        await model.submit(using: client)

        await model.refreshMatch(using: client)

        #expect(model.matchState == .loaded(nil))
        #expect(await AppStubURLProtocol.recorded(host: Self.host).isEmpty)
    }

    @Test("a TV season question in the preview is answered on the draft")
    func answeringThePreviewQuestion() async throws {
        await AppStubURLProtocol.set(host: Self.host) { _ in (Data(Self.seasonQuestion.utf8), 200, [:]) }
        let model = LogViewModel(extract: { _ in Self.diplomat() })
        let client = try await makeClient()
        model.updateText("Episodes 1 and 2 of The Diplomat")
        await model.submit(using: client)
        let before = model.matchKey

        await model.refreshMatch(using: client)
        guard case .question(let question) = model.matchState else {
            Issue.record("Expected a question, got \(model.matchState)")
            return
        }
        model.answerMatchQuestion(try #require(question.options.first))

        #expect(model.draft.season == 3)
        #expect(model.matchKey != before)
    }

    @Test("editing goes back to the text and keeps it")
    func editKeepsText() async throws {
        let model = LogViewModel(extract: { _ in LogDraft(kind: "wine", title: "Rioja") })
        model.updateText("Rioja")
        await model.submit(using: try await makeClient())

        model.edit()

        #expect(model.phase == .idle)
        #expect(model.text == "Rioja")
    }

    @Test("a request the server rejects shows its message")
    func showsServerMessage() async throws {
        await AppStubURLProtocol.set(host: Self.host) { _ in
            (Data(#"{"message":"No TV series found for that title."}"#.utf8), 422, ["Content-Type": "application/json"])
        }
        let model = LogViewModel(extract: { _ in Self.diplomat() })
        model.updateText("Watched episode 1 of Zzzz")

        let client = try await makeClient()
        await model.submit(using: client)
        await model.confirm(using: client)

        #expect(model.phase == .failed("No TV series found for that title."))
    }

    @Test("an unavailable model says so and sends nothing")
    func modelUnavailable() async throws {
        await AppStubURLProtocol.set(host: Self.host) { _ in (Data(), 500, [:]) }
        let model = LogViewModel(extract: { _ in throw LogExtractionError.unavailable })
        model.updateText("A pint of Guinness")

        await model.submit(using: try await makeClient())

        #expect(model.phase == .failed("Apple Intelligence isn’t available."))
        #expect(await AppStubURLProtocol.recorded(host: Self.host).isEmpty)
    }

    @Test("undo reads each event's version and deletes it")
    func undoDeletesEvents() async throws {
        await AppStubURLProtocol.set(host: Self.host) { request in
            switch request.httpMethod {
            case "POST": return (Data(Self.logged.utf8), 201, [:])
            case "GET": return (Data("{}".utf8), 200, ["ETag": "\"v1\""])
            default: return (Data(#"{"id":"e1","deleted_at":"2026-10-19T20:00:00+00:00"}"#.utf8), 200, [:])
            }
        }
        let model = LogViewModel(extract: { _ in Self.diplomat() })
        let client = try await makeClient()
        model.updateText("Episodes 1 and 2 of The Diplomat")
        await model.submit(using: client)
        await model.confirm(using: client)

        await model.undo(using: client)

        #expect(model.phase == .undone)
        let requests = await AppStubURLProtocol.recorded(host: Self.host)
        #expect(requests.map(\.httpMethod) == ["POST", "GET", "DELETE", "GET", "DELETE"])
        #expect(requests.filter { $0.httpMethod == "DELETE" }.allSatisfy { $0.value(forHTTPHeaderField: "If-Match") == "\"v1\"" })
    }

    @Test("a failed undo keeps the entry and its Undo")
    func failedUndoKeepsEntry() async throws {
        await AppStubURLProtocol.set(host: Self.host) { request in
            request.httpMethod == "POST"
                ? (Data(Self.logged.utf8), 201, [:])
                : (Data(#"{"message":"unavailable"}"#.utf8), 500, [:])
        }
        let model = LogViewModel(extract: { _ in Self.diplomat() })
        let client = try await makeClient()
        model.updateText("Episodes 1 and 2 of The Diplomat")
        await model.submit(using: client)
        await model.confirm(using: client)

        await model.undo(using: client)

        guard case .logged(let outcome) = model.phase else {
            Issue.record("Expected the entry to stay logged, got \(model.phase)")
            return
        }
        #expect(outcome.events.count == 2)
        #expect(model.undoError != nil)
    }

    private nonisolated static let winePreview = """
    {"status":"preview","match":{"kind":"wine","state":"matched",\
    "best":{"title":"Raquillet Mercurey","detail":"Mercurey, France","rating":4.1,"url":"https://www.vivino.com/en/x/w/1","image":null,"score":1},\
    "candidates":[{"title":"Raquillet Rouge","detail":null,"rating":3.9,"url":"https://www.vivino.com/en/y/w/2","image":null,"score":0.67}]}}
    """

    private nonisolated static let seasonQuestion = """
    {"status":"needs_clarification","field":"season","question":"Which season?",\
    "options":[{"label":"Season 3","value":3},{"label":"Season 2","value":2}],"suggested":3}
    """

    private nonisolated static let logged = """
    {"status":"logged","events":[\
    {"id":"e1","action":"watched_episode","title":"The Diplomat S03E01","time":"2026-10-19T19:30:00+00:00"},\
    {"id":"e2","action":"watched_episode","title":"The Diplomat S03E02","time":"2026-10-19T19:30:00+00:00"}],\
    "missing_episodes":[]}
    """

    private func makeClient() async throws -> APIClient {
        let tokenStore = KeychainTokenStore(
            service: "co.cronx.sparkapp.tests.log.\(UUID().uuidString)",
            account: "test",
            accessGroup: nil
        )
        try await tokenStore.store(access: "token", refresh: "refresh", expiresIn: 3_600)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStubURLProtocol.self]
        let suite = "spark.etag.log.\(UUID().uuidString)"
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
