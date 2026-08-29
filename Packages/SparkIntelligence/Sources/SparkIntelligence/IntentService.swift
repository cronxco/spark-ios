import Foundation
import SparkKit
import SwiftData

/// Shared service providing API access and SwiftData reads to AppIntents.
/// Constructed on-demand in each intent's `perform()` — intents may run in
/// the extension process where `AppModel.shared` is not available.
@MainActor
public struct IntentService {
    public let apiClient: APIClient
    private let tokenStore: KeychainTokenStore

    public init() {
        let store = KeychainTokenStore()
        let cache = ETagCache()
        self.tokenStore = store
        self.apiClient = APIClient(tokenStore: store, etagCache: cache)
    }

    // MARK: - SwiftData reads

    public func todaySnapshot() -> TodayIntentSnapshot? {
        guard let container = try? SparkDataStore.makeContainer() else { return nil }
        let context = ModelContext(container)
        let dateStr = todayDateString()
        let descriptor = FetchDescriptor<CachedDaySummary>(
            predicate: #Predicate { $0.date == dateStr }
        )
        guard let cached = (try? context.fetch(descriptor))?.first,
              let summary = try? cached.decoded()
        else { return nil }
        return TodayIntentSnapshot(summary: summary)
    }

    // MARK: - Entity reads (shared by EntityQueries, Spotlight indexing, Tools)

    /// Opens a fresh `ModelContext` against the shared App Group container, or
    /// `nil` when the store is unavailable (e.g. first launch before migration).
    public static func makeContext() -> ModelContext? {
        guard let container = try? SparkDataStore.makeContainer() else { return nil }
        return ModelContext(container)
    }

    public static func eventEntities(matching ids: [String]? = nil, limit: Int = 50) -> [EventEntity] {
        guard let context = makeContext() else { return [] }
        var descriptor = FetchDescriptor<CachedEvent>(sortBy: [SortDescriptor(\.time, order: .reverse)])
        if ids == nil { descriptor.fetchLimit = limit }
        let rows = (try? context.fetch(descriptor)) ?? []
        let filtered = ids.map { idSet in rows.filter { idSet.contains($0.id) } } ?? rows
        return filtered.map(EventEntity.init(cached:))
    }

    public static func eventEntities(query: String, limit: Int = 25) -> [EventEntity] {
        let needle = query.lowercased()
        return eventEntities(limit: 500)
            .filter { entity in
                entity.title.lowercased().contains(needle)
                    || (entity.summary?.lowercased().contains(needle) ?? false)
                    || entity.tags.contains { $0.lowercased().contains(needle) }
            }
            .prefix(limit)
            .map { $0 }
    }

    public static func blockEntities(matching ids: [String]? = nil, limit: Int = 50) -> [BlockEntity] {
        guard let context = makeContext() else { return [] }
        var descriptor = FetchDescriptor<CachedBlock>(sortBy: [SortDescriptor(\.time, order: .reverse)])
        if ids == nil { descriptor.fetchLimit = limit }
        let rows = (try? context.fetch(descriptor)) ?? []
        let filtered = ids.map { idSet in rows.filter { idSet.contains($0.id) } } ?? rows
        return filtered.map(BlockEntity.init(cached:))
    }

    public static func placeEntities(matching ids: [String]? = nil, limit: Int = 100) -> [PlaceEntity] {
        guard let context = makeContext() else { return [] }
        var descriptor = FetchDescriptor<CachedPlace>(sortBy: [SortDescriptor(\.title)])
        if ids == nil { descriptor.fetchLimit = limit }
        let rows = (try? context.fetch(descriptor)) ?? []
        let filtered = ids.map { idSet in rows.filter { idSet.contains($0.id) } } ?? rows
        return filtered.map(PlaceEntity.init(cached:))
    }

    public static func metricEntities(matching ids: [String]? = nil, limit: Int = 100) -> [MetricEntity] {
        guard let context = makeContext() else { return [] }
        var descriptor = FetchDescriptor<CachedMetric>(sortBy: [SortDescriptor(\.lastEventAt, order: .reverse)])
        if ids == nil { descriptor.fetchLimit = limit }
        let rows = (try? context.fetch(descriptor)) ?? []
        let filtered = ids.map { idSet in rows.filter { idSet.contains($0.identifier) } } ?? rows
        return filtered.map(MetricEntity.init(cached:))
    }

    public static func anomalyEntities(matching ids: [String]? = nil, limit: Int = 100) -> [AnomalyEntity] {
        guard let context = makeContext() else { return [] }
        var descriptor = FetchDescriptor<CachedAnomaly>(sortBy: [SortDescriptor(\.detectedAt, order: .reverse)])
        if ids == nil { descriptor.fetchLimit = limit }
        let rows = (try? context.fetch(descriptor)) ?? []
        let filtered = ids.map { idSet in rows.filter { idSet.contains($0.id) } } ?? rows
        return filtered.map(AnomalyEntity.init(cached:))
    }

    public static func integrationEntities(matching ids: [String]? = nil) -> [IntegrationEntity] {
        guard let context = makeContext() else { return [] }
        let rows = (try? context.fetch(FetchDescriptor<CachedIntegration>())) ?? []
        let filtered = ids.map { idSet in rows.filter { idSet.contains($0.service) } } ?? rows
        return filtered.map(IntegrationEntity.init(cached:))
    }

    public static func moneyAccountEntities(matching ids: [String]? = nil, limit: Int = 100) -> [MoneyAccountEntity] {
        guard let context = makeContext() else { return [] }
        var descriptor = FetchDescriptor<CachedMoneyAccount>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        if ids == nil { descriptor.fetchLimit = limit }
        let rows = (try? context.fetch(descriptor)) ?? []
        let filtered = ids.map { idSet in rows.filter { idSet.contains($0.id) } } ?? rows
        return filtered.map(MoneyAccountEntity.init(cached:))
    }

    public static func spendSummaryEntities(matching ids: [String]? = nil, limit: Int = 30) -> [SpendSummaryEntity] {
        guard let context = makeContext() else { return [] }
        var descriptor = FetchDescriptor<CachedDaySummary>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        if ids == nil { descriptor.fetchLimit = limit }
        let rows = (try? context.fetch(descriptor)) ?? []
        let filtered = ids.map { idSet in
            rows.filter { idSet.contains("spend:\($0.date)") }
        } ?? rows
        return filtered.compactMap(SpendSummaryEntity.init(cached:))
    }

    public static func daySummaryEntities(matching ids: [String]? = nil, limit: Int = 30) -> [DaySummaryEntity] {
        guard let context = makeContext() else { return [] }
        var descriptor = FetchDescriptor<CachedDaySummary>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        if ids == nil { descriptor.fetchLimit = limit }
        let rows = (try? context.fetch(descriptor)) ?? []
        let filtered = ids.map { idSet in rows.filter { idSet.contains($0.date) } } ?? rows
        return filtered.map(DaySummaryEntity.init(cached:))
    }

    /// Optimistically marks the cached anomaly acknowledged so the Today screen
    /// and Spotlight reflect the change before the next sync.
    public static func markAnomalyAcknowledged(id: String) {
        guard let context = makeContext() else { return }
        let descriptor = FetchDescriptor<CachedAnomaly>(predicate: #Predicate { $0.id == id })
        guard let row = (try? context.fetch(descriptor))?.first else { return }
        row.acknowledgedAt = .now
        try? context.save()
    }

    // MARK: - UserDefaults routing (for open-app intents)

    public static func setPendingRoute(_ route: String) {
        UserDefaults(suiteName: "group.co.cronx.sparkapp")?
            .set(route, forKey: "spark.pendingRoute")
    }

    // MARK: - Helpers

    private func todayDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }
}

// MARK: - Typed snapshot for intents (avoids AnyCodable in intent code)

public struct TodayIntentSnapshot: Sendable {
    public let sleepScore: Int?
    public let sleepDurationMinutes: Int?
    public let steps: Int?
    public let stepsGoal: Int
    public let spentToday: Double?
    public let currency: String
    public let anomalyCount: Int

    public init(summary: DaySummary) {
        let health = summary.sections.health?.objectValue
        sleepScore = health?["sleep_score"]?.objectValue?["score"]?.intValue
        let durSec = health?["sleep_duration"]?.objectValue?["duration_seconds"]?.intValue
        sleepDurationMinutes = durSec.map { $0 / 60 }

        let activity = summary.sections.activity?.objectValue
        steps = activity?["steps"]?.objectValue?["value"]?.intValue
        stepsGoal = activity?["steps"]?.objectValue?["goal"]?.intValue ?? 10_000

        let money = summary.sections.money?.objectValue
        spentToday = money?["total_spend"]?.doubleValue
        currency = money?["transactions"]?.arrayValue?.first?.objectValue?["currency"]?.stringValue ?? "GBP"

        anomalyCount = summary.anomalies.count
    }

    public var sleepDurationDisplay: String {
        guard let mins = sleepDurationMinutes else { return "unknown duration" }
        let h = mins / 60; let m = mins % 60
        return m == 0 ? "\(h) hours" : "\(h) hours and \(m) minutes"
    }

    public var spentDisplay: String {
        guard let amount = spentToday else { return "nothing" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: abs(amount))) ?? "\(amount)"
    }
}
