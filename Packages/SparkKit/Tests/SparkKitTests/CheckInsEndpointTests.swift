import Foundation
import Testing
@testable import SparkKit

@Suite("Check-in endpoints")
struct CheckInsEndpointTests {
    @Test("submit endpoint encodes retrospective timestamp")
    func submitEndpointEncodesOccurredAt() throws {
        let occurredAt = try #require(ISO8601DateFormatter().date(from: "2026-05-04T08:00:00Z"))
        let endpoint = CheckInsEndpoint.submit(CheckInRequest(
            period: .morning,
            physical: 4,
            mental: 5,
            date: "2026-05-04",
            occurredAt: occurredAt,
            latitude: 51.5,
            longitude: -0.1,
            address: "London",
            notes: "Good start"
        ))

        let body = try #require(endpoint.body)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]

        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/check-ins")
        #expect(endpoint.contentType == "application/json")
        #expect(object?["period"] as? String == "morning")
        #expect(object?["date"] as? String == "2026-05-04")
        #expect(object?["occurred_at"] as? String == "2026-05-04T08:00:00Z")
        #expect(object?["physical"] as? Int == 4)
        #expect(object?["mental"] as? Int == 5)
    }
}
