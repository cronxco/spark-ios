import Foundation
import Testing
@testable import SparkKit

@Suite("Metrics endpoints")
struct MetricsEndpointTests {
    @Test("list endpoint targets bare metrics collection")
    func listEndpoint() {
        let endpoint = MetricsEndpoint.list()

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/metrics")
        #expect(endpoint.query.isEmpty)
    }

    @Test("detail endpoint carries requested range")
    func detailEndpointRange() throws {
        let endpoint = MetricsEndpoint.detail(identifier: "oura.sleep_score", range: .sevenDays)

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/metrics/oura.sleep_score")
        let range = try #require(endpoint.query.first { $0.name == "range" })
        #expect(range.value == "7d")
    }

    @Test("metric decodes mobile metadata")
    func metricDecodesMobileMetadata() throws {
        let json = """
        [
          {
            "id": "met_1",
            "identifier": "oura.sleep_score",
            "display_name": "Sleep Score",
            "service": "oura",
            "domain": "health",
            "action": "sleep_score",
            "unit": "score",
            "event_count": 42,
            "mean": 86.4,
            "last_event_at": "2026-05-03T12:09:00Z"
          }
        ]
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let metrics = try decoder.decode([Metric].self, from: Data(json.utf8))
        let metric = try #require(metrics.first)

        #expect(metric.identifier == "oura.sleep_score")
        #expect(metric.displayName == "Sleep Score")
        #expect(metric.domain == "health")
        #expect(metric.eventCount == 42)
        #expect(metric.lastEventAt != nil)
    }
}
