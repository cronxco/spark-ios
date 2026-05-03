import Foundation
import Testing
@testable import SparkKit

@Suite("Search response decoding")
struct SearchResponseDecodingTests {
    @Test("decodes top-level array payload")
    func decodesArrayPayload() throws {
        let json = """
        [
          { "kind": "event", "id": "evt_1", "title": "Morning run", "subtitle": "07:00" },
          { "kind": "metric", "identifier": "oura.sleep_score", "title": "Sleep score", "subtitle": "82" }
        ]
        """

        let response = try JSONDecoder().decode(SearchResponse.self, from: Data(json.utf8))
        #expect(response.results.count == 2)
    }

    @Test("decodes wrapped results payload")
    func decodesWrappedPayload() throws {
        let json = """
        {
          "results": [
            { "kind": "integration", "id": "int_1", "title": "Monzo", "subtitle": "Connected" }
          ]
        }
        """

        let response = try JSONDecoder().decode(SearchResponse.self, from: Data(json.utf8))
        #expect(response.results.count == 1)
        if case .integration(let hit) = try #require(response.results.first) {
            #expect(hit.title == "Monzo")
        } else {
            Issue.record("Expected an integration hit.")
        }
    }

    @Test("decodes grouped backend format")
    func decodesGroupedBackendPayload() throws {
        let json = """
        {
          "mode": "default",
          "query": "Test",
          "events": [
            {
              "id": "evt_1",
              "service": "monzo",
              "domain": "money",
              "action": "purchase",
              "target": { "id": "obj_1", "title": "Costa Coffee", "concept": "merchant" }
            }
          ],
          "objects": [
            {
              "id": "obj_2",
              "concept": "article",
              "type": "knowledge",
              "title": "Testing in Swift"
            }
          ],
          "integrations": [
            {
              "id": "int_1",
              "service": "monzo",
              "name": "Monzo",
              "instance_type": "bank",
              "status": "active"
            }
          ],
          "metrics": [
            {
              "id": "met_1",
              "identifier": "oura.sleep_score",
              "display_name": "Sleep Score",
              "service": "oura",
              "action": "sleep_score",
              "unit": "points",
              "event_count": 30,
              "mean": 82.5,
              "last_event_at": "2026-05-03T00:00:00Z"
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(SearchResponse.self, from: Data(json.utf8))
        #expect(response.results.count == 4)

        if case .event(let hit) = response.results[0] {
            #expect(hit.title == "Costa Coffee")
            #expect(hit.domain == "money")
        } else {
            Issue.record("Expected an event hit at index 0.")
        }

        if case .object(let hit) = response.results[1] {
            #expect(hit.title == "Testing in Swift")
            #expect(hit.concept == "article")
        } else {
            Issue.record("Expected an object hit at index 1.")
        }

        if case .integration(let hit) = response.results[2] {
            #expect(hit.title == "Monzo")
            #expect(hit.service == "monzo")
        } else {
            Issue.record("Expected an integration hit at index 2.")
        }

        if case .metric(let hit) = response.results[3] {
            #expect(hit.identifier == "oura.sleep_score")
            #expect(hit.title == "Sleep Score")
            #expect(hit.subtitle == "points")
        } else {
            Issue.record("Expected a metric hit at index 3.")
        }
    }
}
