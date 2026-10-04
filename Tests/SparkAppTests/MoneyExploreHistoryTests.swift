import Foundation
import Testing

@testable import Spark
@testable import SparkKit

@Suite("Money Explore history", .serialized)
@MainActor
struct MoneyExploreHistoryTests {
    private nonisolated static let host = "money-history.spark.test"
    private nonisolated static let accountJSON = #"{"id":"pot","title":"Savings","kind":"monzo_pot","currency":"GBP","is_negative_balance":false,"updated_at":"2026-10-04T12:00:00Z","latest_balance":{"id":"new","balance":400000,"currency":"GBP","time":"2026-10-04T23:59:59Z"}}"#

    @Test("Explore follows the balance cursor before building a graph")
    func loadsOlderPages() async throws {
        await AppStubURLProtocol.set(host: Self.host) { request in
            if request.url?.path.hasSuffix("/balances") == true {
                let cursor = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "cursor" }?.value
                let json = cursor == nil
                    ? #"{"data":[{"id":"new","balance":400000,"currency":"GBP","time":"2026-10-04T23:59:59Z"}],"has_more":true,"next_cursor":"older"}"#
                    : #"{"data":[{"id":"old","balance":399000,"currency":"GBP","time":"2026-09-03T23:59:59Z"}],"has_more":false,"next_cursor":null}"#
                return (Data(json.utf8), 200, [:])
            }
            return (Data("{\"data\":[\(Self.accountJSON)],\"has_more\":false}".utf8), 200, [:])
        }
        let model = try await makeModel()
        await model.load()
        #expect(model.netWorthHistory.map(\.total) == [399000, 400000])
        let cutoff = date("2026-09-04T00:00:00Z")
        #expect(model.history(since: cutoff).map(\.total) == [399000, 400000])
        #expect(model.history(since: cutoff).first?.date == cutoff)
        let requests = await AppStubURLProtocol.recorded(host: Self.host)
        #expect(requests.filter { $0.url?.path.hasSuffix("/balances") == true }.count == 2)
    }

    @Test("failed history is an error, never a partial graph")
    func rejectsFailedHistory() async throws {
        await AppStubURLProtocol.set(host: Self.host) { request in
            if request.url?.path.hasSuffix("/balances") == true {
                return (Data(#"{"message":"unavailable"}"#.utf8), 403, [:])
            }
            return (Data("{\"data\":[\(Self.accountJSON)],\"has_more\":false}".utf8), 200, [:])
        }
        let model = try await makeModel()
        await model.load()
        #expect(model.netWorth == 400000)
        #expect(model.netWorthHistory.isEmpty)
        guard case .error = model.historyState else {
            Issue.record("Failed balances must not be treated as zero")
            return
        }
    }

    @Test("a repeated cursor cannot produce a complete-looking graph")
    func rejectsTruncatedPaging() async throws {
        await AppStubURLProtocol.set(host: Self.host) { request in
            if request.url?.path.hasSuffix("/balances") == true {
                return (Data(#"{"data":[],"has_more":true,"next_cursor":"same"}"#.utf8), 200, [:])
            }
            return (Data("{\"data\":[\(Self.accountJSON)],\"has_more\":false}".utf8), 200, [:])
        }
        let model = try await makeModel()
        await model.load()
        #expect(model.netWorthHistory.isEmpty)
        guard case .error = model.historyState else {
            Issue.record("Repeated cursors must fail complete history loads")
            return
        }
    }

    @Test("complete paging fails when its page budget is exhausted")
    func rejectsPageBudget() async throws {
        await AppStubURLProtocol.set(host: Self.host) { _ in
            (Data(#"{"data":[],"has_more":true,"next_cursor":"older"}"#.utf8), 200, [:])
        }
        let client = try await makeClient()
        await #expect(throws: CursorPagingError.self) {
            try await client.collectAllPages(maxPages: 1, requireComplete: true) { cursor in
                MoneyEndpoint.balances(accountId: "pot", cursor: cursor)
            }
        }
    }

    @Test("daily aggregation keeps the newest observation and signs debt")
    func latestWithinDayWins() throws {
        let savings = try account(id: "savings")
        let debt = try account(id: "debt", negative: true)
        let foreign = try account(id: "foreign", currency: "USD")
        let history = MoneyExploreViewModel.buildHistory(accounts: [savings, debt, foreign], balances: [
            "savings": [try entry(id: "b", balance: 120, time: "2026-10-04T20:00:00Z"),
                        try entry(id: "a", balance: 100, time: "2026-10-04T10:00:00Z")],
            "debt": [try entry(id: "c", balance: 20, time: "2026-10-04T20:00:00Z")],
            "foreign": [try entry(id: "d", balance: 1000, time: "2026-10-04T20:00:00Z", currency: "USD")],
        ], calendar: calendar())
        #expect(history.map(\.total) == [100])
        let ties = MoneyExploreViewModel.buildHistory(accounts: [savings], balances: [
            "savings": [try entry(id: "b", balance: 120, time: "2026-10-04T20:00:00Z"),
                        try entry(id: "a", balance: 100, time: "2026-10-04T20:00:00Z")],
        ], calendar: calendar())
        #expect(ties.map(\.total) == [120])
    }

    @Test("UTC snapshot dates stay on their date in British Summer Time")
    func respectsSnapshotDay() throws {
        var london = Calendar(identifier: .gregorian)
        london.timeZone = TimeZone(identifier: "Europe/London")!
        let savings = try account(id: "savings")
        for explicitDate in [nil, "2026-10-04"] as [String?] {
            let history = MoneyExploreViewModel.buildHistory(accounts: [savings], balances: [
                "savings": [try entry(id: "a", balance: 100, time: "2026-10-04T23:59:59Z", snapshotDate: explicitDate)],
            ], calendar: london)
            #expect(london.component(.day, from: try #require(history.first).date) == 4)
        }
    }

    @Test("sparse manual balances carry forward across daily bank observations")
    func carriesSparseBalances() throws {
        let manual = try account(id: "manual")
        let daily = try account(id: "daily")
        let history = MoneyExploreViewModel.buildHistory(accounts: [manual, daily], balances: [
            "manual": [try entry(id: "a", balance: 90000, time: "2026-01-04T23:59:59Z")],
            "daily": [try entry(id: "b", balance: 416000, time: "2026-09-03T23:59:59Z"),
                      try entry(id: "c", balance: 415000, time: "2026-10-04T23:59:59Z")],
        ], calendar: calendar())
        #expect(history.map(\.total) == [90000, 506000, 505000])
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }

    private func account(id: String, negative: Bool = false, currency: String = "GBP") throws -> MoneyAccount {
        let json = "{\"id\":\"\(id)\",\"title\":\"\(id)\",\"kind\":\"manual_account\",\"currency\":\"\(currency)\",\"is_negative_balance\":\(negative),\"updated_at\":\"2026-10-04T12:00:00Z\"}"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MoneyAccount.self, from: Data(json.utf8))
    }

    private func entry(id: String, balance: Double, time: String, currency: String = "GBP", snapshotDate: String? = nil) throws -> BalanceEntry {
        let dateField = snapshotDate.map { ",\"date\":\"\($0)\"" } ?? ""
        let json = "{\"id\":\"\(id)\",\"balance\":\(balance),\"currency\":\"\(currency)\",\"time\":\"\(time)\"\(dateField)}"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BalanceEntry.self, from: Data(json.utf8))
    }

    private func makeModel() async throws -> MoneyExploreViewModel {
        MoneyExploreViewModel(apiClient: try await makeClient())
    }

    private func makeClient() async throws -> APIClient {
        let store = KeychainTokenStore(service: "spark.tests.money.\(UUID().uuidString)", account: "test", accessGroup: nil)
        try await store.store(access: "token", refresh: "refresh", expiresIn: 3600)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStubURLProtocol.self]
        return APIClient(
            environment: APIEnvironment(
                baseURL: URL(string: "https://\(Self.host)/api/v1/mobile")!,
                oauthAuthorizeURL: URL(string: "https://\(Self.host)/oauth/authorize")!, name: "test"
            ),
            session: URLSession(configuration: configuration), tokenStore: store,
            etagCache: ETagCache(defaults: UserDefaults(suiteName: "spark.tests.money.\(UUID().uuidString)")!)
        )
    }
}
