import Foundation
import Observation
import OSLog
import SparkKit

struct NetWorthPoint: Identifiable {
    let id = UUID()
    let date: Date
    let total: Double
}

@Observable
@MainActor
final class MoneyExploreViewModel {
    enum LoadState { case idle, loading, loaded, error(String) }

    private(set) var accounts: [MoneyAccount] = []
    private(set) var netWorthHistory: [NetWorthPoint] = []
    #if DEBUG
        private(set) var rawFeedEntries: [RawFeedJSONEntry] = []
    #endif
    private(set) var loadState: LoadState = .idle
    private(set) var historyState: LoadState = .idle

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "MoneyExplore")

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var netWorth: Double {
        accounts.reduce(0.0) { sum, account in
            let balance = account.latestBalance?.balance ?? 0
            return sum + (account.isNegativeBalance ? -abs(balance) : balance)
        }
    }

    func load() async {
        guard case .idle = loadState else { return }
        loadState = .loading
        do {
            #if DEBUG
                let response = try await apiClient.requestWithRawResponse(MoneyEndpoint.accounts())
                accounts = response.decoded.data
                rawFeedEntries = [
                    RawFeedJSONEntry(title: "GET /money/accounts", body: response.utf8Body)
                ]
            #else
                let response = try await apiClient.request(MoneyEndpoint.accounts())
                accounts = response.data
            #endif
            loadState = .loaded
            await buildNetWorthHistory()
        } catch where error.isAPICancellation {
            loadState = .idle
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Money explore load failed: \(String(describing: error))")
            loadState = .error((error as? LocalizedError)?.errorDescription ?? "Couldn't load accounts.")
        }
    }

    func refresh() async {
        accounts = []
        netWorthHistory = []
        #if DEBUG
            rawFeedEntries = []
        #endif
        loadState = .idle
        historyState = .idle
        await load()
    }

    func accountCreated(_ account: MoneyAccount) {
        accounts.append(account)
    }

    private func buildNetWorthHistory() async {
        guard !accounts.isEmpty else { return }
        historyState = .loading

        var allBalances: [String: [BalanceEntry]] = [:]
        let snapAccounts = accounts

        #if DEBUG
            var rawBalances: [String: String] = [:]
            await withTaskGroup(of: (String, [BalanceEntry], String?).self) { group in
                for account in snapAccounts {
                    group.addTask { [apiClient] in
                        do {
                            let response = try await apiClient.requestWithRawResponse(MoneyEndpoint.balances(accountId: account.id))
                            return (account.id, response.decoded.data, response.utf8Body)
                        } catch {
                            return (account.id, [], nil)
                        }
                    }
                }
                for await (id, entries, rawBody) in group {
                    allBalances[id] = entries
                    rawBalances[id] = rawBody
                }
            }
            rawFeedEntries.append(contentsOf: snapAccounts.compactMap { account in
                guard let rawBody = rawBalances[account.id] else { return nil }
                return RawFeedJSONEntry(title: "GET /money/accounts/\(account.id)/balances", body: rawBody)
            })
        #else
            await withTaskGroup(of: (String, [BalanceEntry]).self) { group in
                for account in snapAccounts {
                    group.addTask { [apiClient] in
                        let response = try? await apiClient.request(MoneyEndpoint.balances(accountId: account.id))
                        return (account.id, response?.data ?? [])
                    }
                }
                for await (id, entries) in group {
                    allBalances[id] = entries
                }
            }
        #endif

        let cal = Calendar.current
        var dateMap: [Date: [String: Double]] = [:]

        for account in snapAccounts {
            let entries = allBalances[account.id] ?? []
            for entry in entries {
                let day = cal.startOfDay(for: entry.time)
                let adjusted = account.isNegativeBalance ? -abs(entry.balance) : entry.balance
                if dateMap[day] == nil { dateMap[day] = [:] }
                dateMap[day]![account.id] = adjusted
            }
        }

        let sortedDays = dateMap.keys.sorted()
        var running: [String: Double] = [:]

        netWorthHistory = sortedDays.compactMap { day in
            if let updates = dateMap[day] {
                for (id, balance) in updates { running[id] = balance }
            }
            guard !running.isEmpty else { return nil }
            return NetWorthPoint(date: day, total: running.values.reduce(0, +))
        }

        historyState = .loaded
    }
}
