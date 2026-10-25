import Foundation
import Testing
@testable import SparkKit

@Suite("Log endpoint")
struct LogEndpointTests {
    @Test("submit posts snake_case JSON and omits what was not said")
    func submitEncodesRequest() throws {
        let occurredAt = try #require(ISO8601DateFormatter().date(from: "2026-10-19T19:30:00Z"))
        let endpoint = LogEndpoint.submit(LogRequest(
            kind: .beer,
            idempotencyKey: "key-1",
            title: "Verdant Nebulous Sky",
            occurredAt: occurredAt,
            quantity: 1,
            serving: .can
        ))

        let body = try #require(endpoint.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/log")
        #expect(endpoint.contentType == "application/json")
        #expect(object["kind"] as? String == "beer")
        #expect(object["idempotency_key"] as? String == "key-1")
        #expect(object["title"] as? String == "Verdant Nebulous Sky")
        #expect(object["occurred_at"] as? String == "2026-10-19T19:30:00Z")
        #expect(object["serving"] as? String == "can")
        #expect(object["volume_ml"] == nil)
        #expect(object["episodes"] == nil)
        #expect(object["tvdb_id"] == nil)
    }

    @Test("a TV request carries the season, episodes and chosen series")
    func submitEncodesTelevision() throws {
        let endpoint = LogEndpoint.submit(LogRequest(
            kind: .tv,
            idempotencyKey: "key-2",
            title: "The Diplomat",
            season: 3,
            episodes: [1, 2],
            tvdbID: 371_572
        ))

        let body = try #require(endpoint.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(object["kind"] as? String == "tv")
        #expect(object["season"] as? Int == 3)
        #expect(object["episodes"] as? [Int] == [1, 2])
        #expect(object["tvdb_id"] as? Int == 371_572)
    }

    @Test("people are sent under the backend's with key")
    func submitEncodesPeople() throws {
        let endpoint = LogEndpoint.submit(LogRequest(kind: .wine, idempotencyKey: "key-3", title: "Rioja", people: ["Dan", "Sam"]))

        let body = try #require(endpoint.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(object["with"] as? [String] == ["Dan", "Sam"])
        #expect(object["people"] == nil)
    }

    @Test("a dry run and a chosen match are sent under the backend's keys")
    func submitEncodesDryRun() throws {
        let endpoint = LogEndpoint.submit(LogRequest(
            kind: .wine, idempotencyKey: "key-4", title: "Rioja", rating: 4, dryRun: true, matchURL: "https://www.vivino.com/en/x/w/1"
        ))

        let body = try #require(endpoint.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(object["dry_run"] as? Bool == true)
        #expect(object["match_url"] as? String == "https://www.vivino.com/en/x/w/1")
        #expect(object["rating"] as? Double == 4)
    }

    @Test("decodes a wine preview with its best card and runners-up")
    func decodesWinePreview() throws {
        let json = """
        {
          "status": "preview",
          "match": {
            "kind": "wine", "state": "matched",
            "best": {"title": "Raquillet Mercurey", "detail": "Mercurey, France", "rating": 4.1, "url": "https://www.vivino.com/en/x/w/1", "image": null, "score": 1},
            "candidates": [{"title": "Raquillet Rouge", "detail": null, "rating": 3.9, "url": "https://www.vivino.com/en/y/w/2", "image": null, "score": 0.67}]
          }
        }
        """

        let response = try JSONDecoder().decode(LogResponse.self, from: Data(json.utf8))

        guard case .preview(let match?, _) = response else {
            Issue.record("Expected a preview")
            return
        }
        #expect(match.state == .matched)
        #expect(match.best?.rating == 4.1)
        #expect(match.candidates.map(\.score) == [0.67])
        #expect(match.episodes.isEmpty)
    }

    @Test("decodes a TV preview with episode titles and missing episodes")
    func decodesTelevisionPreview() throws {
        let json = """
        {
          "status": "preview",
          "match": {
            "kind": "tv", "state": "matched", "series": {"id": 371572, "name": "The Diplomat"}, "season": 3,
            "episodes": [{"number": 1, "name": "The Last Straw", "aired": "2026-01-01"}, {"number": 2, "name": null, "aired": null}],
            "missing_episodes": [9]
          }
        }
        """

        let response = try JSONDecoder().decode(LogResponse.self, from: Data(json.utf8))

        guard case .preview(let match?, _) = response else {
            Issue.record("Expected a preview")
            return
        }
        #expect(match.series == LogMatch.Series(id: 371_572, name: "The Diplomat"))
        #expect(match.season == 3)
        #expect(match.episodes.map(\.number) == [1, 2])
        #expect(match.missingEpisodes == [9])
    }

    @Test("a preview with nothing to look up decodes to nil")
    func decodesEmptyPreview() throws {
        let response = try JSONDecoder().decode(LogResponse.self, from: Data(#"{"status": "preview", "match": null}"#.utf8))

        #expect(response == .preview(nil, people: []))
    }

    @Test("a preview decodes how each named person matched")
    func decodesPeopleChecks() throws {
        let json = """
        {
          "status": "preview", "match": null,
          "people": [
            {"name": "Daniel", "state": "existing", "matches": [{"id": "p1", "name": "Daniel"}]},
            {"name": "Dan", "state": "likely", "matches": [{"id": "p1", "name": "Daniel Smith"}]},
            {"name": "Sam", "state": "ambiguous", "matches": [{"id": "p2", "name": "Sam Jones"}, {"id": "p3", "name": "Samantha"}]},
            {"name": "Priya", "state": "new", "matches": []}
          ]
        }
        """

        let response = try JSONDecoder().decode(LogResponse.self, from: Data(json.utf8))

        guard case .preview(nil, let people) = response else {
            Issue.record("Expected a preview")
            return
        }
        #expect(people.map(\.state) == [.existing, .likely, .ambiguous, .new])
        #expect(people[1].matches.map(\.name) == ["Daniel Smith"])
        #expect(people[2].matches.count == 2)
    }

    @Test("board game kind uses the backend spelling")
    func boardGameRawValue() {
        #expect(LogKind.boardGame.rawValue == "board_game")
    }

    @Test("decodes logged events and missing episodes")
    func decodesLogged() throws {
        let json = """
        {
          "status": "logged",
          "events": [
            {"id": "e1", "action": "watched_episode", "title": "The Diplomat S03E01", "time": "2026-10-19T19:30:00+00:00"}
          ],
          "missing_episodes": [9],
          "people": [{"id": "p1", "name": "Dan", "created": false}, {"id": "p2", "name": "Sam", "created": true}]
        }
        """

        let response = try JSONDecoder().decode(LogResponse.self, from: Data(json.utf8))

        #expect(response == .logged(
            events: [LoggedEvent(id: "e1", action: "watched_episode", title: "The Diplomat S03E01", time: "2026-10-19T19:30:00+00:00")],
            missingEpisodes: [9],
            people: [LoggedPerson(id: "p1", name: "Dan"), LoggedPerson(id: "p2", name: "Sam", created: true)]
        ))
    }

    @Test("a logged response without missing episodes decodes to none")
    func decodesLoggedWithoutMissing() throws {
        let json = #"{"status": "logged", "events": [{"id": "e1", "action": "drank_wine", "title": null, "time": null}]}"#

        let response = try JSONDecoder().decode(LogResponse.self, from: Data(json.utf8))

        #expect(response == .logged(events: [LoggedEvent(id: "e1", action: "drank_wine")], missingEpisodes: [], people: []))
    }

    @Test("decodes a season question with the suggested season")
    func decodesSeasonClarification() throws {
        let json = """
        {
          "status": "needs_clarification",
          "field": "season",
          "question": "Which season?",
          "options": [{"label": "Season 3", "value": 3}, {"label": "Season 2", "value": 2}],
          "suggested": 3
        }
        """

        let response = try JSONDecoder().decode(LogResponse.self, from: Data(json.utf8))

        guard case .needsClarification(let question, _) = response else {
            Issue.record("Expected a clarification")
            return
        }
        #expect(question.field == .season)
        #expect(question.question == "Which season?")
        #expect(question.options.map(\.value) == [3, 2])
        #expect(question.suggested == 3)
    }

    @Test("decodes a series question with overviews and no suggestion")
    func decodesSeriesClarification() throws {
        let json = """
        {
          "status": "needs_clarification",
          "field": "series",
          "question": "Which \\"The Office\\"?",
          "options": [
            {"label": "The Office (2005)", "value": 73244, "name": "The Office", "overview": "A mockumentary.", "image": null},
            {"label": "The Office (2001)", "value": 78107, "name": "The Office", "overview": null, "image": "https://example.com/a.jpg"}
          ]
        }
        """

        let response = try JSONDecoder().decode(LogResponse.self, from: Data(json.utf8))

        guard case .needsClarification(let question, _) = response else {
            Issue.record("Expected a clarification")
            return
        }
        #expect(question.field == .series)
        #expect(question.suggested == nil)
        #expect(question.options.first?.overview == "A mockumentary.")
        #expect(question.options.last?.image == "https://example.com/a.jpg")
    }

    @Test("an unknown status fails to decode")
    func rejectsUnknownStatus() {
        let json = #"{"status": "queued"}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LogResponse.self, from: Data(json.utf8))
        }
    }

    @Test("a note is sent as a reflection with its body, time and people")
    func submitEncodesReflection() throws {
        let occurredAt = try #require(ISO8601DateFormatter().date(from: "2026-10-24T19:00:00Z"))
        let endpoint = LogEndpoint.submit(LogRequest(
            kind: .reflection, idempotencyKey: "key-r", title: "", occurredAt: occurredAt, people: ["Dan"],
            body: "Went to Drop Project with Dan"
        ))

        let body = try #require(endpoint.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(object["kind"] as? String == "reflection")
        #expect(object["body"] as? String == "Went to Drop Project with Dan")
        #expect(object["with"] as? [String] == ["Dan"])
        #expect(object["occurred_at"] != nil)
    }

    @Test("other kinds send no body")
    func submitOmitsBody() throws {
        let endpoint = LogEndpoint.submit(LogRequest(kind: .wine, idempotencyKey: "key-w", title: "Rioja"))

        let body = try #require(endpoint.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(object["body"] == nil)
    }
}
