import Foundation

public enum MoneyEndpoint {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// GET /money/accounts — non-archived accounts with latest balance.
    /// Cursor-paged; use `APIClient.collectAllPages` for the whole list.
    public static func accounts(limit: Int? = nil, cursor: String? = nil) -> Endpoint<MoneyAccountsResponse> {
        var query: [URLQueryItem] = []
        if let limit {
            query.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(method: .get, path: "/money/accounts", query: query)
    }

    /// GET /money/net-worth?compare=1month
    public static func netWorth(compare: NetWorthWindow = .oneMonth) -> Endpoint<NetWorthResponse> {
        Endpoint(
            method: .get,
            path: "/money/net-worth",
            query: [URLQueryItem(name: "compare", value: compare.rawValue)]
        )
    }

    /// GET /money/accounts/{id} — single account with latest balance.
    public static func account(id: String) -> Endpoint<MoneyAccountResponse> {
        Endpoint(method: .get, path: "/money/accounts/\(id)")
    }

    /// GET /money/accounts/{id}/balances — cursor-paginated balance history.
    public static func balances(accountId: String, cursor: String? = nil, limit: Int? = nil) -> Endpoint<Page<BalanceEntry>> {
        var query: [URLQueryItem] = []
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let limit {
            query.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        return Endpoint(method: .get, path: "/money/accounts/\(accountId)/balances", query: query)
    }

    /// POST /money/accounts — create a manual account.
    public static func createAccount(_ request: CreateAccountRequest) -> Endpoint<MoneyAccountResponse> {
        Endpoint(
            method: .post,
            path: "/money/accounts",
            body: try? encoder.encode(request),
            contentType: "application/json"
        )
    }

    /// PATCH /money/accounts/{id} — update a manual account.
    public static func updateAccount(id: String, _ request: UpdateAccountRequest) -> Endpoint<MoneyAccountResponse> {
        Endpoint(
            method: .patch,
            path: "/money/accounts/\(id)",
            body: try? encoder.encode(request),
            contentType: "application/json"
        )
    }

    /// DELETE /money/accounts/{id} — archive a manual account.
    public static func deleteAccount(id: String) -> Endpoint<MessageResponse> {
        Endpoint(method: .delete, path: "/money/accounts/\(id)")
    }

    /// POST /money/accounts/{id}/balances — add a balance update.
    ///
    /// The idempotency key is minted when the endpoint is built, so the
    /// client's own transport retries share it and replay the first response
    /// rather than recording the balance twice. A new tap is a new intent and
    /// gets a new key.
    public static func addBalance(
        accountId: String,
        _ request: AddBalanceRequest,
        idempotencyKey: UUID = UUID()
    ) -> Endpoint<BalanceEntryResponse> {
        Endpoint(
            method: .post,
            path: "/money/accounts/\(accountId)/balances",
            body: try? encoder.encode(request),
            contentType: "application/json",
            headers: ["Idempotency-Key": idempotencyKey.uuidString]
        )
    }

    // MARK: - Plan

    /// GET /money/plan — safe to spend, card cover, budgets, pots and interest in one call.
    public static func plan() -> Endpoint<MoneyPlanResponse> {
        Endpoint(method: .get, path: "/money/plan")
    }

    /// GET /money/spending?month=yyyy-MM — the spending-only list.
    public static func spending(month: String? = nil) -> Endpoint<SpendingResponse> {
        var query: [URLQueryItem] = []
        if let month {
            query.append(URLQueryItem(name: "month", value: month))
        }
        return Endpoint(method: .get, path: "/money/spending", query: query)
    }

    /// POST /money/buffer/preview — what Add to buffer would move. Moves nothing.
    public static func previewBuffer(eventIds: [String]) -> Endpoint<BufferPreviewResponse> {
        Endpoint(
            method: .post,
            path: "/money/buffer/preview",
            body: try? encoder.encode(BufferRequest(eventIds: eventIds)),
            contentType: "application/json"
        )
    }

    /// POST /money/buffer — moves money into the buffer pot.
    ///
    /// The key is minted when the endpoint is built so transport retries replay
    /// the first response; a fresh tap on the confirmation is a new intent.
    public static func addToBuffer(
        eventIds: [String],
        confirmedTotal: Int,
        idempotencyKey: UUID = UUID()
    ) -> Endpoint<BufferResult> {
        Endpoint(
            method: .post,
            path: "/money/buffer",
            body: try? encoder.encode(BufferRequest(eventIds: eventIds, confirmedTotal: confirmedTotal)),
            contentType: "application/json",
            headers: ["Idempotency-Key": idempotencyKey.uuidString]
        )
    }

    /// PATCH /money/pots/{id} — mark or unmark the pot used as the card buffer.
    public static func setCardBuffer(potId: String, enabled: Bool) -> Endpoint<CardBufferPotResponse> {
        Endpoint(
            method: .patch,
            path: "/money/pots/\(potId)",
            body: try? encoder.encode(CardBufferPotRequest(cardBuffer: enabled)),
            contentType: "application/json"
        )
    }
}
