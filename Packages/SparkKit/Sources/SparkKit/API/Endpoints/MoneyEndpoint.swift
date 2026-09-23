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
    public static func balances(accountId: String, cursor: String? = nil) -> Endpoint<Page<BalanceEntry>> {
        var query: [URLQueryItem] = []
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
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
}
