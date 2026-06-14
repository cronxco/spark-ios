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

    @Test("timezone endpoint uses the focused mobile route")
    func timezoneEndpoint() {
        let endpoint = CheckInsEndpoint.timezone()

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/check-ins/timezone")
        #expect(!endpoint.usesETag)
    }

    @Test("timezone acknowledgement encodes the server contract")
    func acknowledgeTimezoneEndpoint() throws {
        let endpoint = CheckInsEndpoint.acknowledgeTimezone(
            TimezoneAcknowledgementRequest(
                timezone: "America/New_York",
                previousTimezone: "Europe/London",
                deviceId: "device-123"
            )
        )

        let body = try #require(endpoint.body)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]

        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/check-ins/timezone")
        #expect(endpoint.contentType == "application/json")
        #expect(object?["timezone"] as? String == "America/New_York")
        #expect(object?["previous_timezone"] as? String == "Europe/London")
        #expect(object?["device_id"] as? String == "device-123")
    }

    @Test("timezone acknowledgement decodes fallback and event states")
    func timezoneAcknowledgementDecoding() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let fallback = try decoder.decode(
            TimezoneAcknowledgement.self,
            from: Data("""
            {
              "timezone": "Europe/London",
              "source": "profile",
              "acknowledged_at": null,
              "event_id": null,
              "device_id": null
            }
            """.utf8)
        )
        let acknowledged = try decoder.decode(
            TimezoneAcknowledgement.self,
            from: Data("""
            {
              "timezone": "America/New_York",
              "source": "time_travel",
              "acknowledged_at": "2026-06-14T09:08:39Z",
              "event_id": "event-123",
              "device_id": "device-123"
            }
            """.utf8)
        )

        #expect(fallback.timezone == "Europe/London")
        #expect(fallback.acknowledgedAt == nil)
        #expect(acknowledged.source == "time_travel")
        #expect(acknowledged.eventId == "event-123")
        #expect(acknowledged.deviceId == "device-123")
    }

    @Test("timezone prompt comparison suppresses only the exact rejected pair")
    func timezonePromptPolicy() {
        let rejected = TimezoneChangePolicy.rejectionKey(
            acknowledgedTimezone: "Europe/London",
            deviceTimezone: "America/New_York"
        )

        #expect(!TimezoneChangePolicy.shouldPrompt(
            acknowledgedTimezone: "Europe/London",
            deviceTimezone: "Europe/London",
            rejectedKey: nil
        ))
        #expect(!TimezoneChangePolicy.shouldPrompt(
            acknowledgedTimezone: "Europe/London",
            deviceTimezone: "America/New_York",
            rejectedKey: rejected
        ))
        #expect(TimezoneChangePolicy.shouldPrompt(
            acknowledgedTimezone: "Europe/London",
            deviceTimezone: "America/Los_Angeles",
            rejectedKey: rejected
        ))
        #expect(TimezoneChangePolicy.shouldPrompt(
            acknowledgedTimezone: "America/New_York",
            deviceTimezone: "Europe/London",
            rejectedKey: rejected
        ))
    }
}
