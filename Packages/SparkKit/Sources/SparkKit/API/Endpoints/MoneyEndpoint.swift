import Foundation

public enum MoneyEndpoint {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// GET /money/accounts — all non-archived accounts with latest balance.
    public static func accounts() -> Endpoint<MoneyAccountsResponse> {
        Endpoint(method: .get, path: "/money/accounts")
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
    public static func addBalance(accountId: String, _ request: AddBalanceRequest) -> Endpoint<BalanceEntryResponse> {
        Endpoint(
            method: .post,
            path: "/money/accounts/\(accountId)/balances",
            body: try? encoder.encode(request),
            contentType: "application/json"
        )
    }
}
