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

    @Test("detail endpoint canonicalizes legacy identifiers")
    func detailEndpointCanonicalizesLegacyIdentifiers() {
        #expect(MetricsEndpoint.detail(identifier: "sleep.score").path == "/metrics/oura.sleep_score")
        #expect(MetricsEndpoint.detail(identifier: "health.steps").path == "/metrics/oura.steps")
        #expect(MetricsEndpoint.detail(identifier: "money.spend").path == "/metrics/monzo.spend_daily")
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

    @Test("metric detail skips null daily values but preserves null-valued anomalies")
    func metricDetailDecodesNullDailyValues() throws {
        let json = """
        {
          "metric": "oura.spo2",
          "service": "oura",
          "action": "had_spo2",
          "display_name": "SpO2",
          "domain": "health",
          "unit": "%",
          "baseline": {
            "normal_lower": 96.2,
            "normal_upper": 99.7
          },
          "daily_values": [
            {
              "date": "2026-03-02",
              "value": 96.642,
              "is_anomaly": false
            },
            {
              "date": "2026-03-03",
              "value": null,
              "is_anomaly": true
            },
            {
              "date": "2026-03-04",
              "value": 97.957,
              "is_anomaly": false
            }
          ]
        }
        """

        let detail = try JSONDecoder().decode(MetricDetail.self, from: Data(json.utf8))

        #expect(detail.id == "oura.spo2")
        #expect(detail.series.map(\.value) == [96.642, 97.957])
        #expect(detail.today == 97.957)
        #expect(detail.yesterday == 96.642)
        #expect(detail.anomalies.count == 1)
        #expect(detail.anomalies.first?.id == "2026-03-03")
        #expect(detail.anomalies.first?.value == nil)
    }

    @Test("metric detail tolerates empty array summary")
    func metricDetailDecodesEmptyArraySummary() throws {
        let json = """
        {
          "action": "finished_reading",
          "baseline": {
            "mean": 4.67,
            "normal_lower": 3.56,
            "normal_upper": 5.79,
            "sample_days": 86,
            "stddev": 0.56
          },
          "daily_values": [
            {
              "date": "2026-05-23",
              "is_anomaly": true,
              "value": null,
              "vs_baseline_pct": -100
            }
          ],
          "metric": "goodreads.finished_reading./5",
          "range": {
            "from": "2026-05-19",
            "to": "2026-05-25"
          },
          "service": "goodreads",
          "summary": [],
          "unit": "/5"
        }
        """

        let detail = try JSONDecoder().decode(MetricDetail.self, from: Data(json.utf8))

        #expect(detail.id == "goodreads.finished_reading./5")
        #expect(detail.title == "Finished Reading")
        #expect(detail.average30d == nil)
        #expect(detail.baseline?.low == 3.56)
        #expect(detail.baseline?.high == 5.79)
        #expect(detail.series.isEmpty)
        #expect(detail.anomalies.count == 1)
        #expect(detail.anomalies.first?.value == nil)
    }
}
