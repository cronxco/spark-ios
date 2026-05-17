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
            let data = try await apiClient.request(MoneyEndpoint.accounts())
            accounts = data.data
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

        await withTaskGroup(of: (String, [BalanceEntry]).self) { group in
            for account in snapAccounts {
                group.addTask { [apiClient] in
                    do {
                        let page = try await apiClient.request(MoneyEndpoint.balances(accountId: account.id))
                        return (account.id, page.data)
                    } catch {
                        return (account.id, [])
                    }
                }
            }
            for await (id, entries) in group {
                allBalances[id] = entries
            }
        }

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
