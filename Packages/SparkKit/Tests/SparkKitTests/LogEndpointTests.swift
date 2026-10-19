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
          "missing_episodes": [9]
        }
        """

        let response = try JSONDecoder().decode(LogResponse.self, from: Data(json.utf8))

        #expect(response == .logged(
            events: [LoggedEvent(id: "e1", action: "watched_episode", title: "The Diplomat S03E01", time: "2026-10-19T19:30:00+00:00")],
            missingEpisodes: [9]
        ))
    }

    @Test("a logged response without missing episodes decodes to none")
    func decodesLoggedWithoutMissing() throws {
        let json = #"{"status": "logged", "events": [{"id": "e1", "action": "drank_wine", "title": null, "time": null}]}"#

        let response = try JSONDecoder().decode(LogResponse.self, from: Data(json.utf8))

        #expect(response == .logged(events: [LoggedEvent(id: "e1", action: "drank_wine")], missingEpisodes: []))
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

        guard case .needsClarification(let question) = response else {
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

        guard case .needsClarification(let question) = response else {
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
}
