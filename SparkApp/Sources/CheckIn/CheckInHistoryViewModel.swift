import Foundation
import Observation
import SparkKit
import SwiftData

enum CheckInHistoryState: Equatable {
    case idle
    case loading
    case error(String)
}

@MainActor
@Observable
final class CheckInHistoryViewModel {
    private(set) var days: [CheckInHistoryDay] = []
    private(set) var state: CheckInHistoryState = .idle
    private(set) var streakCount: Int = 0

    private let apiClient: APIClient
    private let container: ModelContainer

    init(apiClient: APIClient, container: ModelContainer) {
        self.apiClient = apiClient
        self.container = container
    }

    func load() async {
        state = .loading
        loadFromCache()
        await fetchFromAPI()
    }

    private func loadFromCache() {
        let context = ModelContext(container)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -29, to: .now) ?? .now
        let fromKey = Self.isoDate(thirtyDaysAgo)
        let toKey = Self.isoDate(.now)
        let descriptor = FetchDescriptor<CachedCheckIn>(
            predicate: #Predicate { $0.date >= fromKey && $0.date <= toKey },
            sortBy: [SortDescriptor(\.date)]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        days = buildHistoryDays(rows: rows, fromKey: fromKey, toKey: toKey)
        computeStreak()
        state = .idle
    }

    private func fetchFromAPI() async {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -29, to: .now) ?? .now
        let fromKey = Self.isoDate(thirtyDaysAgo)
        let toKey = Self.isoDate(.now)
        do {
            let response = try await apiClient.request(
                CheckInsEndpoint.history(from: fromKey, to: toKey)
            )
            let context = ModelContext(container)
            for day in response.days {
                upsertPeriod(day.morning, date: day.date, period: .morning, in: context)
                upsertPeriod(day.afternoon, date: day.date, period: .afternoon, in: context)
            }
            try? context.save()
            loadFromCache()
        } catch APIError.notModified {
            state = .idle
        } catch is CancellationError {
            state = .idle
        } catch {
            state = days.isEmpty ? .error("Couldn't load history") : .idle
        }
    }

    private func upsertPeriod(_ period: CheckInHistoryPeriod, date: String, period checkInPeriod: CheckInPeriod, in context: ModelContext) {
        CachedCheckIn.upsert(
            date: date,
            period: checkInPeriod,
            completed: period.completed,
            physical: period.physical,
            mental: period.mental,
            notes: period.notes,
            eventId: period.eventId,
            in: context
        )
    }

    private func buildHistoryDays(rows: [CachedCheckIn], fromKey: String, toKey: String) -> [CheckInHistoryDay] {
        var grouped: [String: [CachedCheckIn]] = [:]
        for row in rows {
            grouped[row.date, default: []].append(row)
        }

        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: .now)) ?? .now
        var result: [CheckInHistoryDay] = []

        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: thirtyDaysAgo) else { continue }
            let key = Self.isoDate(day)
            let dayRows = grouped[key] ?? []
            let morningRow = dayRows.first { $0.period == "morning" }
            let afternoonRow = dayRows.first { $0.period == "afternoon" }
            result.append(CheckInHistoryDay(
                date: key,
                morning: periodFromRow(morningRow),
                afternoon: periodFromRow(afternoonRow)
            ))
        }
        return result.reversed()
    }

    private func periodFromRow(_ row: CachedCheckIn?) -> CheckInHistoryPeriod {
        guard let row, row.completed else {
            return CheckInHistoryPeriod(completed: false)
        }
        return CheckInHistoryPeriod(
            completed: true,
            physical: row.physical,
            mental: row.mental,
            combined: row.physical.flatMap { phy in row.mental.map { phy + $0 } },
            notes: row.notes,
            eventId: row.eventId
        )
    }

    private func computeStreak() {
        var streak = 0
        for day in days {
            if day.morning.completed || day.afternoon.completed {
                streak += 1
            } else {
                break
            }
        }
        streakCount = streak
    }

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
