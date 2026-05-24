import Foundation
import Testing
@testable import SparkKit

@Suite("UpToSpeed endpoints")
struct UpToSpeedEndpointTests {
    @Test("feed endpoint produces GET /up-to-speed with optional date query")
    func feedEndpoint() {
        let endpoint = UpToSpeedEndpoint.feed(date: "2026-05-23")

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/up-to-speed")
        #expect(endpoint.query.contains(URLQueryItem(name: "date", value: "2026-05-23")))
    }

    @Test("feed endpoint omits date query when nil")
    func feedEndpointNoDate() {
        let endpoint = UpToSpeedEndpoint.feed()

        #expect(endpoint.query.isEmpty)
    }

    @Test("markRead encodes items wrapper with type and id")
    func markReadEndpoint() throws {
        let refs = [
            UpToSpeedReadRef(type: .flintDigest, id: "uuid-1"),
            UpToSpeedReadRef(type: .anomaly, id: "uuid-2"),
            UpToSpeedReadRef(type: .newsSummary, id: "uuid-3"),
        ]
        let endpoint = UpToSpeedEndpoint.markRead(refs)
        let body = try #require(endpoint.body)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let items = try #require(object?["items"] as? [[String: String]])

        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/up-to-speed/read")
        #expect(endpoint.contentType == "application/json")
        #expect(items.count == 3)
        #expect(items[0]["type"] == "flint_digest")
        #expect(items[0]["id"] == "uuid-1")
        #expect(items[1]["type"] == "anomaly")
        #expect(items[2]["type"] == "news_summary")
    }

    @Test("acknowledge endpoint encodes note and suppress_until")
    func acknowledgeEndpoint() throws {
        let suppressDate = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let endpoint = AnomaliesEndpoint.acknowledge(
            id: "trend-uuid-1",
            note: "Expected variation",
            suppressUntil: suppressDate
        )
        let body = try #require(endpoint.body)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: String]

        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/anomalies/trend-uuid-1/acknowledge")
        #expect(endpoint.contentType == "application/json")
        #expect(object?["note"] == "Expected variation")
        #expect(object?["suppress_until"] == "2026-06-01")
    }

    @Test("acknowledge endpoint omits nil fields")
    func acknowledgeEndpointNilFields() throws {
        let endpoint = AnomaliesEndpoint.acknowledge(id: "trend-uuid-1")
        let body = try #require(endpoint.body)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]

        #expect(object?["note"] == nil)
        #expect(object?["suppress_until"] == nil)
    }
}
