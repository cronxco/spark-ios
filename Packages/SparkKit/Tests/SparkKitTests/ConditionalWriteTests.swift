import Foundation
import Testing
@testable import SparkKit

/// PSEC-07 — the conditional-write contract.
///
/// The backend guards destructive and last-write-wins mutations with a strong
/// resource version and answers 428 without one. The revert that produced the
/// current `main` removed `Endpoint.headers` entirely, so the client had no way
/// to send `If-Match` at all and every guarded write failed.
@Suite("Conditional writes")
struct ConditionalWriteTests {
    @Test("withIfMatch sets the header")
    func withIfMatchSetsHeader() {
        let endpoint = Endpoint<EmptyResponse>(method: .delete, path: "/notifications/abc")
            .withIfMatch("\"v1\"")

        #expect(endpoint.headers["If-Match"] == "\"v1\"")
    }

    @Test("withIfMatch is a no-op for a nil version")
    func withIfMatchIgnoresNil() {
        let endpoint = Endpoint<EmptyResponse>(method: .delete, path: "/notifications/abc")
            .withIfMatch(nil)

        #expect(endpoint.headers["If-Match"] == nil)
    }

    @Test("withIfMatch is a no-op for an empty version")
    func withIfMatchIgnoresEmpty() {
        let endpoint = Endpoint<EmptyResponse>(method: .delete, path: "/notifications/abc")
            .withIfMatch("")

        #expect(endpoint.headers["If-Match"] == nil)
    }

    @Test("withIfMatch preserves every other field")
    func withIfMatchPreservesFields() throws {
        let body = Data("{\"a\":1}".utf8)
        let original = Endpoint<EmptyResponse>(
            method: .patch,
            path: "/settings/notifications",
            query: [URLQueryItem(name: "scope", value: "all")],
            body: body,
            contentType: "application/json",
            requiresAuth: true,
            headers: ["X-Existing": "kept"]
        )

        let conditional = original.withIfMatch("\"v9\"")

        #expect(conditional.method == .patch)
        #expect(conditional.path == "/settings/notifications")
        #expect(conditional.query.first?.value == "all")
        #expect(conditional.body == body)
        #expect(conditional.contentType == "application/json")
        #expect(conditional.requiresAuth)
        #expect(conditional.headers["X-Existing"] == "kept")
        #expect(conditional.headers["If-Match"] == "\"v9\"")
    }
}

@Suite("Precondition errors")
struct PreconditionErrorTests {
    private let url = URL(string: "https://spark.cronx.co/api/v1/mobile/notifications/abc")!

    @Test("428 is a missing precondition")
    func missingPrecondition() {
        let error = APIError.httpStatus(428, nil, url)

        #expect(error.isPreconditionRequired)
        #expect(!error.isPreconditionFailed)
        #expect(error.isPreconditionFailure)
    }

    @Test("412 is a stale precondition")
    func stalePrecondition() {
        let error = APIError.httpStatus(412, nil, url)

        #expect(error.isPreconditionFailed)
        #expect(!error.isPreconditionRequired)
        #expect(error.isPreconditionFailure)
    }

    @Test("other statuses are not precondition failures", arguments: [400, 403, 404, 422, 500])
    func otherStatuses(status: Int) {
        let error = APIError.httpStatus(status, nil, url)

        #expect(!error.isPreconditionFailure)
    }
}

@Suite("Notification endpoints")
struct NotificationsEndpointTests {
    @Test("delete carries the version as If-Match")
    func deleteCarriesIfMatch() {
        let endpoint = NotificationsEndpoint.delete(id: "abc", version: "\"v1\"")

        #expect(endpoint.method == .delete)
        #expect(endpoint.path == "/notifications/abc")
        #expect(endpoint.headers["If-Match"] == "\"v1\"")
    }

    @Test("the idempotent transitions send no precondition")
    func idempotentTransitionsSendNoPrecondition() {
        // These previously required If-Match server-side and so returned 428
        // for every shipped client. Marking read cannot lose an update, so the
        // precondition was removed rather than satisfied.
        #expect(NotificationsEndpoint.markRead(id: "abc").headers["If-Match"] == nil)
        #expect(NotificationsEndpoint.markAllRead().headers["If-Match"] == nil)
    }

    @Test("preferences update carries the user version")
    func preferencesUpdateCarriesIfMatch() {
        let endpoint = NotificationsPreferencesEndpoint.update(
            NotificationPreferences(deliveryMode: .workHours),
            version: "\"user-v3\""
        )

        #expect(endpoint.method == .patch)
        #expect(endpoint.path == "/settings/notifications")
        #expect(endpoint.headers["If-Match"] == "\"user-v3\"")
    }
}

@Suite("Session endpoint")
struct SessionEndpointTests {
    @Test("logout posts to /logout with no precondition")
    func logoutShape() {
        let endpoint = SessionEndpoint.logout()

        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/logout")
        #expect(endpoint.requiresAuth)
        // Signing out must never be blocked by a precondition.
        #expect(endpoint.headers.isEmpty)
    }
}

@Suite("NotificationItem decoding")
struct NotificationItemVersionTests {
    private func decode(_ json: String) throws -> NotificationItem {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(NotificationItem.self, from: Data(json.utf8))
    }

    @Test("decodes the version the list payload now carries")
    func decodesVersion() throws {
        let item = try decode("""
        {
            "id": "abc",
            "title": "Integration Completed",
            "body": null,
            "domain": "money",
            "is_read": false,
            "received_at": "2026-01-15T09:30:00Z",
            "entity": null,
            "version": "\\"9f2c\\""
        }
        """)

        #expect(item.version == "\"9f2c\"")
    }

    @Test("stays decodable against a server that predates the field")
    func decodesWithoutVersion() throws {
        let item = try decode("""
        {
            "id": "abc",
            "title": "Integration Completed",
            "body": null,
            "domain": "money",
            "is_read": false,
            "received_at": "2026-01-15T09:30:00Z",
            "entity": null
        }
        """)

        #expect(item.version == nil)
    }
}
