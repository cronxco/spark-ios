import Foundation
import Testing
@testable import SparkKit

/// Decodes the fixtures shared with spark (`tests/Fixtures/search-contract/v1`).
/// The server test pins their keys; this suite proves the client reads them.
@Suite("Search contract v1")
struct SearchContractFixtureTests {
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/SearchContract/v1")
        )
        return try Data(contentsOf: url)
    }

    private func decode(_ name: String) throws -> SearchResponse {
        try JSONDecoder().decode(SearchResponse.self, from: fixture(name))
    }

    @Test("the request names the contract version and the canonical query")
    func requestUsesCanonicalParameters() throws {
        let endpoint = SearchEndpoint.query(text: "coffee", mode: .metrics, limit: 10)
        let items = Dictionary(uniqueKeysWithValues: endpoint.query.map { ($0.name, $0.value) })

        #expect(items["contract_version"] == "1")
        #expect(items["query"] == "coffee")
        #expect(items["mode"] == "metric")
        #expect(items["limit"] == "10")
        #expect(items["q"] == nil)
    }

    @Test("decodes every kind in the complete fixture")
    func decodesCompleteFixture() throws {
        let response = try decode("complete")

        #expect(response.schemaVersion == 1)
        #expect(response.execution == SearchExecution(status: .complete, fallbackReason: nil))
        #expect(!response.isDegraded)
        #expect(response.droppedKinds.isEmpty)
        #expect(response.results.count == 7)

        let sections = response.results.map(\.sectionLabel)
        #expect(sections == ["Events", "Objects", "Blocks", "Metrics", "Integrations", "Places", "Tags"])

        if case .metric(let hit) = response.results[3] {
            #expect(hit.identifier == "oura.sleep_score")
            #expect(hit.subtitle == "points")
        } else {
            Issue.record("Expected a metric hit at index 3.")
        }

        if case .tag(let hit) = response.results[6] {
            #expect(hit.name == "coffee")
            #expect(hit.subtitle == "3 items")
        } else {
            Issue.record("Expected a tag hit at index 6.")
        }
    }

    @Test("a degraded semantic search is reported with its reason")
    func decodesDegradedFixture() throws {
        let response = try decode("degraded")

        #expect(response.isDegraded)
        #expect(response.execution?.fallbackReason == "embedding_failed")
        #expect(response.results.count == 1)
    }

    @Test("an empty result is a valid page")
    func decodesEmptyFixture() throws {
        let response = try decode("empty")

        #expect(response.results.isEmpty)
        #expect(response.execution?.status == .complete)
    }

    @Test("an unknown kind is dropped and the rest of the page still renders")
    func unknownKindDoesNotBlankThePage() throws {
        let response = try decode("forward-compat-unknown-kind")

        #expect(response.results.count == 2)
        #expect(response.droppedKinds == ["hologram"])
        #expect(response.results.map(\.sectionLabel) == ["Objects", "Events"])
    }

    @Test("a hit that does not match its kind's shape is dropped, not fatal")
    func malformedHitIsDropped() throws {
        let json = """
        {
          "schema_version": 1, "query": "x", "mode": "default",
          "execution": { "status": "complete", "fallback_reason": null },
          "results": [
            { "kind": "event", "title": "no id" },
            { "kind": "object", "id": "o1", "title": "Fine", "subtitle": null, "concept": null }
          ],
          "meta": { "count": 2, "limit": 20 }
        }
        """

        let response = try JSONDecoder().decode(SearchResponse.self, from: Data(json.utf8))

        #expect(response.results.count == 1)
        #expect(response.droppedKinds == ["event"])
    }

    @Test("older grouped payloads still decode and carry no execution")
    func legacyPayloadStillDecodes() throws {
        let json = #"{ "mode": "default", "query": "x", "events": [], "objects": [{ "id": "o1", "title": "T", "concept": "c" }] }"#

        let response = try JSONDecoder().decode(SearchResponse.self, from: Data(json.utf8))

        #expect(response.results.count == 1)
        #expect(response.schemaVersion == nil)
        #expect(response.execution == nil)
    }

    @Test("only connection failures count as offline")
    func connectivityFailures() {
        #expect(URLError(.notConnectedToInternet).isConnectivityFailure)
        #expect(APIError.transport(URLError(.networkConnectionLost)).isConnectivityFailure)
        #expect(!URLError(.timedOut).isConnectivityFailure)
        #expect(!APIError.unauthorized.isConnectivityFailure)
    }
}
