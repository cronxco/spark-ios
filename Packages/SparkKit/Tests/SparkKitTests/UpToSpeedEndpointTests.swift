import Foundation
import Testing
@testable import SparkKit

@Suite("UpToSpeed endpoints")
struct UpToSpeedEndpointTests {
    @Test("feed endpoint produces a bare GET /up-to-speed by default")
    func feedEndpoint() {
        let endpoint = UpToSpeedEndpoint.feed()

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/up-to-speed")
        #expect(endpoint.query.isEmpty)
    }

    @Test("feed endpoint asks for dismissed anomalies when building the recap")
    func feedEndpointIncludeAcknowledged() {
        let endpoint = UpToSpeedEndpoint.feed(includeAcknowledged: true)

        #expect(endpoint.query.contains(URLQueryItem(name: "include_acknowledged", value: "1")))
    }

    @Test("feed endpoint passes a news cap through")
    func feedEndpointNewsLimit() {
        let endpoint = UpToSpeedEndpoint.feed(newsLimit: 5)

        #expect(endpoint.query.contains(URLQueryItem(name: "news_limit", value: "5")))
    }

    @Test("unmark posts the same items wrapper as markRead")
    func unmarkEndpoint() throws {
        let endpoint = UpToSpeedEndpoint.unmark([UpToSpeedReadRef(type: .newsSummary, id: "uuid-9")])

        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/up-to-speed/unmark")

        let body = try #require(endpoint.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let items = try #require(json["items"] as? [[String: Any]])

        #expect(items.count == 1)
        #expect(items[0]["type"] as? String == "news_summary")
        #expect(items[0]["id"] as? String == "uuid-9")
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
