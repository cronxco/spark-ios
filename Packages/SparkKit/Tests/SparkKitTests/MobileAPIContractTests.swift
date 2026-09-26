import Foundation
import Testing
@testable import SparkKit

/// The client side of the mobile API contract the Day tab depends on.
///
/// Fixtures are the shapes the server actually sends — taken from the
/// controllers and `mobile-api.openapi.yaml`, not from what the client once
/// assumed. Two of this client's bugs came from exactly that gap: a
/// `sync_status` typed as a flat object when it is a per-service map, and a
/// questions cursor read from `meta` when it lives at the top level.
private func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try decoder().decode(type, from: Data(json.utf8))
}

// MARK: - Briefing sync status

@Suite("Day summary sync status")
struct DaySummarySyncStatusTests {
    private let payload = """
    {
      "date": "2026-09-20",
      "timezone": "Europe/London",
      "sync_status": {
        "oura": {
          "event_count": 6,
          "last_event_time": "2026-09-20T00:00:00Z",
          "last_updated_at": "2026-09-20T06:10:00Z",
          "freshness_basis": "updated_at",
          "actions": ["had_sleep_score"],
          "as_of": "2026-09-20T06:10:00Z",
          "stale": false
        },
        "apple_health": {
          "event_count": 13,
          "last_event_time": "2026-09-20T00:00:00Z",
          "actions": ["had_step_count"],
          "coverage": "partial",
          "coverage_note": "Last updated 8h ago — data may be incomplete.",
          "as_of": "2026-09-20T00:05:00Z",
          "stale": false
        },
        "monzo": {
          "event_count": 0,
          "last_event_time": null,
          "actions": [],
          "as_of": "2026-09-19T21:00:00Z",
          "stale": true
        }
      },
      "sections": {},
      "anomalies": []
    }
    """

    @Test("decodes every connected service, including one with nothing today")
    func decodesServices() throws {
        let status = try decode(DaySummary.self, payload).syncStatus
        #expect(status.services.count == 3)
        #expect(status.services["monzo"]?.eventCount == 0)
        #expect(status.services["monzo"]?.lastEventTime == nil)
        #expect(status.services["oura"]?.asOf != nil)
        #expect(status.services["apple_health"]?.coverageNote?.hasPrefix("Last updated") == true)
    }

    @Test("stale is the server's call, whatever the clock says")
    func staleIsBehind() throws {
        let status = try decode(DaySummary.self, payload).syncStatus
        #expect(status.isBehind("monzo") == true)
        #expect(status.isBehind("oura") == false)
    }

    /// The morning this was built for: Apple Health reached recently enough
    /// not to be stale, but its day is only partly in — 211 steps.
    @Test("a partial day is behind even when the service is not stale")
    func partialIsBehind() throws {
        let status = try decode(DaySummary.self, payload).syncStatus
        #expect(status.services["apple_health"]?.stale == false)
        #expect(status.isBehind("apple_health") == true)
    }

    /// Apple Health is pushed, not polled. Servers before push tracking
    /// called it stale all day while calling its day complete, and the
    /// Activity card waited on it with 8,064 steps already in.
    @Test("coverage, where the server gives it, wins over stale")
    func coverageWinsOverStale() throws {
        let status = DaySummary.SyncStatus(services: [
            "apple_health": .init(eventCount: 26, coverage: "complete", stale: true),
        ])
        #expect(status.isBehind("apple_health") == false)
    }

    @Test("a service that is not connected is nothing to wait on")
    func missingIsNotBehind() throws {
        let status = try decode(DaySummary.self, payload).syncStatus
        #expect(status.isBehind("hevy") == false)
    }

    @Test("a server that predates stale still reports partial days")
    func legacyServer() throws {
        let legacy = """
        {"date":"2026-09-20","timezone":"UTC",
         "sync_status":{"apple_health":{"event_count":2,"last_event_time":"2026-09-20T00:00:00Z","actions":[],"coverage":"partial"},
                        "oura":{"event_count":1,"last_event_time":"2026-09-20T00:00:00Z","actions":[]}},
         "sections":{},"anomalies":[]}
        """
        let status = try decode(DaySummary.self, legacy).syncStatus
        #expect(status.isBehind("apple_health") == true)
        #expect(status.isBehind("oura") == false)
    }

    @Test("round-trips through encoding, freshness included")
    func roundTrips() throws {
        let summary = try decode(DaySummary.self, payload)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let again = try decoder().decode(DaySummary.self, from: encoder.encode(summary))
        #expect(again.syncStatus.services["monzo"]?.stale == true)
        #expect(again.syncStatus.services["apple_health"]?.coverage == "partial")
    }
}

// MARK: - Flint

@Suite("Flint contract")
struct FlintContractTests {
    @Test("the digest's opener is the server's, verbatim")
    func digestOpener() throws {
        let digest = try decode(FlintDigest.self, """
        {"event_id":"d1","date":"2026-09-20","period":"morning","kind":"briefing",
         "title":"Morning Digest — Sun 20 Sep",
         "summary":"Good Sunday morning.\\n\\nDRIVING THE DAY\\n\\nToday's genuinely quiet.",
         "opener":"Today's genuinely quiet — nothing on your calendar.",
         "effective_timezone":"Europe/London","block_count":0,"blocks":[]}
        """)
        #expect(digest.opener == "Today's genuinely quiet — nothing on your calendar.")
        #expect(digest.effectiveTimezone == "Europe/London")
    }

    @Test("a blank or missing opener is no opener, so the card hides")
    func blankOpener() throws {
        let blank = try decode(FlintDigest.self, """
        {"event_id":"d1","date":"2026-09-20","title":"t","opener":"   ","block_count":0,"blocks":[]}
        """)
        let missing = try decode(FlintDigest.self, """
        {"event_id":"d1","date":"2026-09-20","title":"t","block_count":0,"blocks":[]}
        """)
        #expect(blank.opener == nil)
        #expect(missing.opener == nil)
    }

    @Test("latest asks for a briefing across dates")
    func latestEndpoint() {
        let endpoint = FlintEndpoint.latest()
        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/flint/digests/latest")
        #expect(endpoint.query == [URLQueryItem(name: "kind", value: "briefing")])
        #expect(FlintEndpoint.latest(kind: nil).query.isEmpty)
    }

    @Test("questions take several statuses and a server-side window")
    func questionsEndpoint() {
        let endpoint = FlintEndpoint.questions(statuses: [.open, .answered], since: "48h")
        #expect(endpoint.path == "/flint/questions")
        #expect(endpoint.query.contains(URLQueryItem(name: "status", value: "open,answered")))
        #expect(endpoint.query.contains(URLQueryItem(name: "since", value: "48h")))
    }

    /// The cursor is top-level on this endpoint. The client read
    /// `meta.next_cursor`, which the server has never sent here, so the Flint
    /// tab only ever loaded the first page of questions.
    @Test("the questions cursor is read from the top level")
    func questionsCursor() throws {
        let page = try decode(FlintQuestionsResponse.self, """
        {"data":[{"id":"q1","digest_id":"d1",
                  "source_digest":{"local_date":"2026-09-19","period":"evening"},
                  "status":"open","title":"The £2,508 transfer from Daniel",
                  "question":"What was the one-off £2,508.27 from Daniel for?",
                  "topic":"money","answer_options":null,"asked_at":"2026-09-19T18:34:14Z",
                  "effective_answer":null,"answer_history":[],"version":"\\"v1\\""}],
         "next_cursor":"page-2","has_more":true,
         "meta":{"effective_timezone":"Europe/London","account_id":"u1"}}
        """)
        #expect(page.nextCursor == "page-2")
        #expect(page.hasMore == true)
        #expect(page.data.first?.title == "The £2,508 transfer from Daniel")
        #expect(page.data.first?.asDigestBlock.title == "The £2,508 transfer from Daniel")
    }

    @Test("the digest history cursor is read from the top level too")
    func historyCursor() throws {
        let page = try decode(FlintDigestHistoryResponse.self, """
        {"data":[{"id":"d1","local_date":"2026-09-19","period":"evening","kind":"briefing",
                  "title":"Evening Digest","summary":null,"generated_at":"2026-09-19T18:34:14Z",
                  "updated_at":"2026-09-19T18:34:14Z","unanswered_question_count":0,"version":"W/v",
                  "freshness":{"state":"fresh","age_seconds":60}}],
         "next_cursor":"page-2","has_more":true,
         "meta":{"from":"2026-08-21","to":"2026-09-19","effective_timezone":"Europe/London","account_id":"u1"}}
        """)
        #expect(page.nextCursor == "page-2")
        #expect(page.meta.nextCursor == nil)
        #expect(page.hasMore)
    }

    @Test("a question without a title falls back to its text as a block")
    func untitledQuestion() throws {
        let page = try decode(FlintQuestionsResponse.self, """
        {"data":[{"id":"q1","digest_id":"d1","source_digest":{"local_date":null,"period":null},
                  "status":"answered","question":"Booked?","answer_options":["Yes","No"],
                  "asked_at":null,"effective_answer":null,"answer_history":[],"version":"v"}],
         "next_cursor":null,"has_more":false,"meta":{"effective_timezone":"UTC","account_id":"u1"}}
        """)
        #expect(page.data.first?.title == nil)
        #expect(page.data.first?.asDigestBlock.title == "Booked?")
        #expect(page.nextCursor == nil)
    }

    @Test("a thread says what it is waiting for, and pages")
    func topics() throws {
        let page = try decode(FlintTopicsResponse.self, """
        {"data":[{"id":"t1","title":"US–Iran escalation","kind":"tactical","status":"active",
                  "watching_for":"A G7 decision on releasing reserves."}],
         "next_cursor":"c2","has_more":true}
        """)
        #expect(page.data.first?.watchingFor == "A G7 decision on releasing reserves.")
        #expect(page.nextCursor == "c2")
        #expect(page.hasMore)

        let endpoint = FlintTopicsEndpoint.list(status: .dormant, cursor: "c2")
        #expect(endpoint.query.contains(URLQueryItem(name: "status", value: "dormant")))
        #expect(endpoint.query.contains(URLQueryItem(name: "cursor", value: "c2")))
    }
}

// MARK: - Money

@Suite("Money contract")
struct MoneyContractTests {
    @Test("accounts page, and carry the pinned flag")
    func accounts() throws {
        let page = try decode(MoneyAccountsResponse.self, """
        {"data":[{"id":"a1","title":"Current Account","kind":"monzo_account","account_type":"current",
                  "currency":"GBP","is_negative_balance":false,"provider":"Monzo","account_number":null,
                  "sort_code":null,"interest_rate":null,"start_date":null,"integration_id":"i1",
                  "is_pinned":true,"latest_balance":null,"updated_at":"2026-09-20T09:00:00Z"}],
         "next_cursor":null,"has_more":false}
        """)
        #expect(page.data.first?.pinned == true)
        #expect(page.hasMore == false)
    }

    @Test("an account from before the flag is simply not pinned")
    func legacyAccount() throws {
        let page = try decode(MoneyAccountsResponse.self, """
        {"data":[{"id":"a1","title":"Savings","kind":"manual_account","account_type":null,"currency":"GBP",
                  "is_negative_balance":false,"provider":null,"account_number":null,"sort_code":null,
                  "interest_rate":null,"start_date":null,"integration_id":null,"latest_balance":null,
                  "updated_at":"2026-09-20T09:00:00Z"}]}
        """)
        #expect(page.data.first?.isPinned == nil)
        #expect(page.data.first?.pinned == false)
        #expect(page.nextCursor == nil)
    }

    @Test("net worth is one request with a comparison window")
    func netWorth() throws {
        let response = try decode(NetWorthResponse.self, """
        {"data":{"total":48210.64,"currency":"GBP",
                 "comparison":{"window":"1month","then":47006.46,"change":1204.18,"change_pct":2.56},
                 "excluded_accounts":1,"as_of":"2026-09-20T09:00:00Z"}}
        """)
        #expect(response.data.total == 48210.64)
        #expect(response.data.comparison?.change == 1204.18)
        #expect(response.data.excludedAccounts == 1)

        let endpoint = MoneyEndpoint.netWorth()
        #expect(endpoint.path == "/money/net-worth")
        #expect(endpoint.query == [URLQueryItem(name: "compare", value: "1month")])
    }

    @Test("a zero starting balance has no percentage change")
    func netWorthWithoutPercentage() throws {
        let response = try decode(NetWorthResponse.self, """
        {"data":{"total":10,"currency":"GBP","comparison":{"window":"1week","then":0,"change":10,"change_pct":null}}}
        """)
        #expect(response.data.comparison?.changePct == nil)
        #expect(response.data.excludedAccounts == 0)
    }

    @Test("pinning sends only the pin")
    func pinRequest() throws {
        let body = try JSONEncoder().encode(UpdateAccountRequest(isPinned: true))
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["is_pinned"] as? Bool == true)
        #expect(json.count == 1)
    }
}

// MARK: - Events

@Suite("Event contract")
struct EventContractTests {
    @Test("carries the server's run key and money direction")
    func groupKeyAndDirection() throws {
        let event = try decode(Event.self, """
        {"id":"e1","service":"monzo","domain":"money","action":"pot_transfer_to","value":2508.27,
         "group_key":"monzo:pot_transfer_to:obj-1","direction":"internal"}
        """)
        #expect(event.groupKey == "monzo:pot_transfer_to:obj-1")
        #expect(event.direction == .internal)
    }

    @Test("a direction the client has not heard of does not fail the event")
    func unknownDirection() throws {
        let event = try decode(Event.self, """
        {"id":"e1","service":"monzo","domain":"money","action":"x","direction":"sideways"}
        """)
        #expect(event.direction == .unknown)
    }
}

// MARK: - Idempotency

@Suite("Idempotency keys")
struct IdempotencyKeyTests {
    @Test("mutations carry a key, and a new intent gets a new one")
    func keysPresentAndDistinct() {
        let request = AddBalanceRequest(balance: 10, date: "2026-09-20")
        let first = MoneyEndpoint.addBalance(accountId: "a1", request)
        let second = MoneyEndpoint.addBalance(accountId: "a1", request)
        let firstKey = first.headers["Idempotency-Key"]
        #expect(firstKey != nil)
        #expect(firstKey != second.headers["Idempotency-Key"])
    }

    @Test("a caller can pin the key, so its own retries share it")
    func keyCanBePinned() {
        let key = UUID()
        let request = AddBalanceRequest(balance: 10, date: "2026-09-20")
        let endpoint = MoneyEndpoint.addBalance(accountId: "a1", request, idempotencyKey: key)
        #expect(endpoint.headers["Idempotency-Key"] == key.uuidString)
    }
}
