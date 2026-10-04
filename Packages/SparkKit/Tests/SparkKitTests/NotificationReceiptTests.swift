import Foundation
import Testing
@testable import SparkKit

@Suite("Notification receipts")
struct NotificationReceiptTests {
    private let id = "9b2f8a5e-3c1d-4f7a-8e6b-2d4c6a8f0e1b"
    private let occurredAt = Date(timeIntervalSince1970: 1_791_018_000) // 2026-10-03T09:00:00Z

    @Test("record endpoint posts only id, event, time and action")
    func recordEndpointEncodesOnlyTelemetry() throws {
        let receipts = [
            try #require(NotificationReceipt(notificationID: id, event: .shown, occurredAt: occurredAt)),
            try #require(NotificationReceipt(notificationID: id, event: .tapped, occurredAt: occurredAt, action: "REAUTH")),
        ]

        let endpoint = NotificationsEndpoint.recordReceipts(receipts)

        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/notifications/receipts")
        #expect(endpoint.contentType == "application/json")
        #expect(endpoint.usesETag == false)

        let body = try #require(endpoint.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(Set(json.keys) == ["receipts"])

        let encoded = try #require(json["receipts"] as? [[String: Any]])
        #expect(encoded.count == 2)
        #expect(Set(encoded[0].keys) == ["notification_id", "event", "occurred_at"])
        #expect(encoded[0]["notification_id"] as? String == id)
        #expect(encoded[0]["event"] as? String == "shown")
        #expect(encoded[0]["occurred_at"] as? String == "2026-10-03T09:00:00Z")
        #expect(Set(encoded[1].keys) == ["notification_id", "event", "occurred_at", "action"])
        #expect(encoded[1]["action"] as? String == "REAUTH")
    }

    @Test("no notification content reaches the request body")
    func noContentIsEncoded() throws {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "Monzo needs reconnecting", "body": "Secret body text"]],
            "spark": ["notification_id": id, "type": "integration_failed", "deep_link": "integration:monzo"],
        ]
        let notificationID = try #require(NotificationReceipt.notificationID(from: userInfo))
        let receipts = NotificationReceipt.receipts(for: .defaultAction, notificationID: notificationID, at: occurredAt)

        let body = try #require(NotificationsEndpoint.recordReceipts(receipts).body)
        let text = try #require(String(data: body, encoding: .utf8))

        #expect(!text.contains("Monzo"))
        #expect(!text.contains("Secret body text"))
        #expect(!text.contains("integration"))
        #expect(!text.contains("title"))
        #expect(!text.contains("body"))
    }

    @Test("notification id comes from the spark envelope")
    func notificationIDFromEnvelope() {
        #expect(NotificationReceipt.notificationID(from: ["spark": ["notification_id": id]]) == id)
        #expect(NotificationReceipt.notificationID(from: ["spark": ["type": "test_push"]]) == nil)
        #expect(NotificationReceipt.notificationID(from: ["spark.notification_id": id]) == nil)
        #expect(NotificationReceipt.notificationID(from: [:]) == nil)
    }

    @Test("ids the server did not issue and unsafe action identifiers are refused")
    func validation() {
        #expect(NotificationReceipt(notificationID: "not-a-uuid", event: .shown) == nil)
        #expect(NotificationReceipt(notificationID: id, event: .tapped, action: "VIEW")?.action == "VIEW")
        #expect(NotificationReceipt(notificationID: id, event: .tapped, action: "Reply: hello there")?.action == nil)
        #expect(NotificationReceipt(notificationID: id, event: .tapped, action: String(repeating: "A", count: 65))?.action == nil)
    }

    @Test("responses map to receipts")
    func responseMapping() {
        let tap = NotificationReceipt.receipts(for: .defaultAction, notificationID: id, at: occurredAt)
        #expect(tap.map(\.event) == [.tapped, .opened])
        #expect(tap.allSatisfy { $0.action == nil })

        let button = NotificationReceipt.receipts(for: .action(identifier: "VIEW", opensApp: true), notificationID: id, at: occurredAt)
        #expect(button.map(\.event) == [.tapped, .opened])
        #expect(button.allSatisfy { $0.action == "VIEW" })

        let background = NotificationReceipt.receipts(for: .action(identifier: "ACK", opensApp: false), notificationID: id, at: occurredAt)
        #expect(background.map(\.event) == [.tapped])

        #expect(NotificationReceipt.receipts(for: .dismiss, notificationID: id).isEmpty)
    }

    @Test("result decodes the server counts")
    func resultDecoding() throws {
        let json = #"{"data":{"recorded":2,"unchanged":1,"not_found":3}}"#
        let result = try JSONDecoder().decode(NotificationReceiptsResult.self, from: Data(json.utf8))
        #expect(result.recorded == 2)
        #expect(result.unchanged == 1)
        #expect(result.notFound == 3)
    }

    @Test("the queue keeps one receipt per notification and event, and is bounded")
    func queueDeduplicatesAndCaps() throws {
        let suite = "NotificationReceiptTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let reporter = NotificationReceiptReporter(defaults: defaults)

        let first = try #require(NotificationReceipt(notificationID: id, event: .shown, occurredAt: occurredAt))
        let repeated = try #require(NotificationReceipt(notificationID: id, event: .shown, occurredAt: occurredAt.addingTimeInterval(60)))
        reporter.enqueue([first])
        reporter.enqueue([repeated])
        #expect(reporter.pending() == [first])

        let many = (0..<(NotificationReceiptReporter.maxPending + 10)).compactMap { _ in
            NotificationReceipt(notificationID: UUID().uuidString.lowercased(), event: .shown, occurredAt: occurredAt)
        }
        reporter.enqueue(many)
        let pending = reporter.pending()
        #expect(pending.count == NotificationReceiptReporter.maxPending)
        #expect(pending.last == many.last)
        #expect(!pending.contains(first))
    }

    @Test("only definite client errors drop queued receipts")
    func permanentRejection() throws {
        let url = try #require(URL(string: "https://spark.cronx.co/api/v1/mobile/notifications/receipts"))
        #expect(NotificationReceiptReporter.isPermanentRejection(.httpStatus(422, nil, url)))
        #expect(NotificationReceiptReporter.isPermanentRejection(.httpStatus(404, nil, url)))
        #expect(!NotificationReceiptReporter.isPermanentRejection(.httpStatus(429, nil, url)))
        #expect(!NotificationReceiptReporter.isPermanentRejection(.httpStatus(403, nil, url)))
        #expect(!NotificationReceiptReporter.isPermanentRejection(.httpStatus(503, nil, url)))
        #expect(!NotificationReceiptReporter.isPermanentRejection(.unauthorized))
    }
}
