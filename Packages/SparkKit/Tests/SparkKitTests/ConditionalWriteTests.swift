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
        #expect(NotificationsEndpoint.markUnread(id: "abc").headers["If-Match"] == nil)
        #expect(NotificationsEndpoint.archive(id: "abc").headers["If-Match"] == nil)
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

@Suite("Notification feed contract")
struct NotificationFeedContractTests {
    @Test("decodes mixed notification and activity rows")
    func decodesMixedFeed() throws {
        let json = """
        {
          "data": [
            {
              "contract_version": 1,
              "id": "notification-id",
              "kind": "notification",
              "type": "integration_failed",
              "stream": "attention",
              "severity": "error",
              "state": "active",
              "title": "Reconnect Monzo",
              "body": "Spark needs your help to resume updates.",
              "is_read": false,
              "occurrence_count": 3,
              "occurred_at": "2026-09-11T09:30:00Z",
              "updated_at": "2026-09-11T09:35:00Z",
              "archived_at": null,
              "entity": {"kind": "integration", "id": "integration-id"},
              "destination": "integration:integration-id",
              "primary_action": {"id": "view", "label": "View"},
              "progress": null,
              "has_technical_detail": true,
              "version": "\\\"v1\\\""
            },
            {
              "contract_version": 1,
              "id": "activity:12",
              "kind": "activity",
              "type": "data_export",
              "stream": "activity",
              "severity": "info",
              "state": "active",
              "title": "Data Export",
              "body": "Preparing your export",
              "is_read": false,
              "occurrence_count": 1,
              "occurred_at": "2026-09-11T09:30:00Z",
              "updated_at": "2026-09-11T09:36:00Z",
              "archived_at": null,
              "entity": null,
              "destination": null,
              "primary_action": null,
              "progress": {"current": 40, "total": 100, "step": "preparing"},
              "has_technical_detail": false,
              "version": "\\\"v2\\\""
            }
          ],
          "next_cursor": null,
          "has_more": false,
          "counts": {
            "unread": 1,
            "unresolved_attention": 1,
            "active_activity": 1,
            "by_stream": {"updates": 0, "activity": 1, "attention": 1, "system": 0}
          }
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let page = try decoder.decode(NotificationFeedPage.self, from: Data(json.utf8))

        #expect(page.data.count == 2)
        #expect(page.data[0].stream == .attention)
        #expect(page.data[0].occurrenceCount == 3)
        #expect(page.data[1].progress?.current == 40)
        #expect(page.counts.unresolvedAttention == 1)
    }

    @Test("builds server-side stream and history filters")
    func buildsFilterQuery() {
        let endpoint = NotificationsEndpoint.feed(
            scope: .history,
            stream: .attention,
            search: "monzo",
            cursor: "next",
            limit: 10
        )

        #expect(endpoint.path == "/notifications/feed")
        #expect(endpoint.query.contains(URLQueryItem(name: "scope", value: "history")))
        #expect(endpoint.query.contains(URLQueryItem(name: "stream", value: "attention")))
        #expect(endpoint.query.contains(URLQueryItem(name: "search", value: "monzo")))
        #expect(endpoint.query.contains(URLQueryItem(name: "cursor", value: "next")))
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
