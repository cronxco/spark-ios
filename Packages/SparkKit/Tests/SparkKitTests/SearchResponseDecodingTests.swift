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
}
