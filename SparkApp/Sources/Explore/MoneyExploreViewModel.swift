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
        accounts.filter { $0.currency == "GBP" }.reduce(0.0) { sum, account in
            let balance = account.latestBalance?.balance ?? 0
            return sum + (account.isNegativeBalance ? -abs(balance) : balance)
        }
    }

    func load() async {
        guard case .idle = loadState else { return }
        loadState = .loading
        do {
            // Accounts are cursor-paged now; the first page is not every account.
            accounts = try await apiClient.collectAllPages(requireComplete: true) { cursor in
                MoneyEndpoint.accounts(cursor: cursor)
            }

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

        let snapAccounts = accounts.filter { $0.currency == "GBP" }
        do {
            let allBalances = try await withThrowingTaskGroup(of: (String, [BalanceEntry]).self) { group in
                for account in snapAccounts {
                    group.addTask { [apiClient] in
                        let entries = try await apiClient.collectAllPages(maxPages: 1_000, requireComplete: true) { cursor in
                            MoneyEndpoint.balances(accountId: account.id, cursor: cursor, limit: 100)
                        }
                        if entries.isEmpty && account.latestBalance != nil {
                            throw CursorPagingError.incompleteHistory
                        }
                        return (account.id, entries)
                    }
                }
                var balances: [String: [BalanceEntry]] = [:]
                for try await (id, entries) in group {
                    balances[id] = entries
                }
                return balances
            }
            netWorthHistory = Self.buildHistory(accounts: snapAccounts, balances: allBalances)
            historyState = .loaded
        } catch where error.isAPICancellation {
            netWorthHistory = []
            historyState = .idle
        } catch {
            netWorthHistory = []
            SparkObservability.captureHandled(error)
            logger.error("Money history load failed: \(String(describing: error))")
            historyState = .error("Couldn't load complete balance history. Pull to refresh to retry.")
        }
    }

    static func buildHistory(
        accounts: [MoneyAccount], balances: [String: [BalanceEntry]], calendar: Calendar = .current
    ) -> [NetWorthPoint] {
        var dateMap: [Date: [String: Double]] = [:]
        for account in accounts where account.currency == "GBP" {
            // The API is newest-first. Apply oldest-first so the last balance
            // of a day wins, with the same ID tie-break as the server.
            let entries = (balances[account.id] ?? []).sorted {
                $0.time == $1.time ? $0.id < $1.id : $0.time < $1.time
            }
            for entry in entries where entry.currency == "GBP" {
                var utc = Calendar(identifier: .gregorian)
                utc.timeZone = TimeZone(secondsFromGMT: 0)!
                let components: DateComponents
                if let date = entry.date {
                    let parts = date.split(separator: "-").compactMap { Int($0) }
                    guard parts.count == 3 else { continue }
                    components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
                } else {
                    // Compatible with servers predating the explicit snapshot date.
                    components = utc.dateComponents([.year, .month, .day], from: entry.time)
                }
                guard let day = calendar.date(from: components) else { continue }
                let adjusted = account.isNegativeBalance ? -abs(entry.balance) : entry.balance
                dateMap[day, default: [:]][account.id] = adjusted
            }
        }
        var running: [String: Double] = [:]
        return dateMap.keys.sorted().map { day in
            for (id, balance) in dateMap[day] ?? [:] { running[id] = balance }
            return NetWorthPoint(date: day, total: running.values.reduce(0, +))
        }
    }

    func history(since cutoff: Date?) -> [NetWorthPoint] {
        guard let cutoff else { return netWorthHistory }
        let later = netWorthHistory.filter { $0.date > cutoff }
        guard let opening = netWorthHistory.last(where: { $0.date <= cutoff }) else { return later }
        return [NetWorthPoint(date: cutoff, total: opening.total)] + later
    }
}
