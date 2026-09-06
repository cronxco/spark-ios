import AppIntents
import CoreSpotlight
import Foundation
import SparkKit
import SwiftData

extension CSSearchableIndex: @retroactive @unchecked Sendable {}

/// Feeds Spark's SwiftData cache into the iOS 27 Spotlight **semantic index**
/// via `IndexedEntity` conformances, so the rebuilt Siri can reason over Spark's
/// personal data (events, blocks, places, integrations, metrics, anomalies, and
/// day summaries) with attribution back to the app.
///
/// Replaces the manual `CSSearchableItem` construction used through Phase 3.
/// Called by BGTaskCoordinator's nightly prefetch task. Indexing only runs while
/// the user is signed in (per privacy decision), and rows older than `ttlDays`
/// are purged on each run.
public enum SpotlightIndexer {
    private static let ttlDays = 30

    // MARK: - Index

    @MainActor
    public static func indexBatch(container: ModelContainer) async {
        _ = await indexBatchWithReport(container: container)
    }

    @MainActor
    public static func indexBatchWithReport(container: ModelContainer) async -> SpotlightIndexReport {
        var report = SpotlightIndexReport(startedAt: .now)

        // Honour auth state: never index personal data while signed out.
        guard await KeychainTokenStore().accessToken() != nil else {
            report.skippedReason = "Signed out"
            report.finishedAt = .now
            return report
        }

        let index = CSSearchableIndex.default()

        await report.record("events") {
            try await index.indexEntities(IntentService.eventEntities(matching: nil, limit: 1000))
        }
        await report.record("blocks") {
            try await index.indexEntities(IntentService.blockEntities(matching: nil, limit: 1000))
        }
        await report.record("places") {
            try await index.indexEntities(IntentService.placeEntities(matching: nil, limit: 1000))
        }
        await report.record("integrations") {
            try await index.indexEntities(IntentService.integrationEntities())
        }
        await report.record("money_accounts") {
            try await index.indexEntities(IntentService.moneyAccountEntities(matching: nil, limit: 1000))
        }
        await report.record("metrics") {
            try await index.indexEntities(IntentService.metricEntities(matching: nil, limit: 1000))
        }
        await report.record("anomalies") {
            try await index.indexEntities(IntentService.anomalyEntities(matching: nil, limit: 1000))
        }
        await report.record("spend_summaries") {
            try await index.indexEntities(IntentService.spendSummaryEntities(matching: nil, limit: 90))
        }
        await report.record("day_summaries") {
            try await index.indexEntities(IntentService.daySummaryEntities(matching: nil, limit: 90))
        }

        report.finishedAt = .now
        return report
    }

    // MARK: - Purge

    /// Removes everything Spark contributed to the system index.
    ///
    /// Called synchronously on sign-out. `purgeStaleItems` also clears the
    /// index when it finds no token, but it only runs from a BGProcessingTask —
    /// so until iOS chose to schedule that, the departing user's events,
    /// blocks, places and metrics stayed searchable from Spotlight.
    @MainActor
    public static func purgeAll() async {
        try? await CSSearchableIndex.default().deleteAllSearchableItems()
    }

    @MainActor
    public static func purgeStaleItems(container: ModelContainer) async {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -ttlDays, to: .now) else { return }
        let context = ModelContext(container)

        // Signed out: drop everything Spark contributed to the index.
        guard await KeychainTokenStore().accessToken() != nil else {
            try? await CSSearchableIndex.default().deleteAllSearchableItems()
            return
        }

        let staleEvents = fetchStale(CachedEvent.self, before: cutoff, in: context)
        await delete(EventEntity.self, ids: staleEvents.map(\.id))

        let staleBlocks = fetchStale(CachedBlock.self, before: cutoff, in: context)
        await delete(BlockEntity.self, ids: staleBlocks.map(\.id))

        let stalePlaces = fetchStale(CachedPlace.self, before: cutoff, in: context)
        await delete(PlaceEntity.self, ids: stalePlaces.map(\.id))

        let staleMetrics = fetchStale(CachedMetric.self, before: cutoff, in: context)
        await delete(MetricEntity.self, ids: staleMetrics.map(\.identifier))

        let staleMoneyAccounts = fetchStale(CachedMoneyAccount.self, before: cutoff, in: context)
        await delete(MoneyAccountEntity.self, ids: staleMoneyAccounts.map(\.id))

        let staleAnomalies = fetchStale(CachedAnomaly.self, before: cutoff, in: context)
        await delete(AnomalyEntity.self, ids: staleAnomalies.map(\.id))

        let staleSummaries = fetchStale(CachedDaySummary.self, before: cutoff, in: context)
        await delete(SpendSummaryEntity.self, ids: staleSummaries.map { "spend:\($0.date)" })
        await delete(DaySummaryEntity.self, ids: staleSummaries.map(\.date))
    }

    // MARK: - Helpers

    @MainActor
    private static func fetchStale<T: PersistentModel>(
        _ type: T.Type,
        before cutoff: Date,
        in context: ModelContext
    ) -> [T] {
        let descriptor = FetchDescriptor<T>()
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { ($0 as? StaleDatable)?.lastSyncedAt ?? .distantFuture < cutoff }
    }

    private static func delete<E: IndexedEntity>(_ type: E.Type, ids: [E.ID]) async {
        guard !ids.isEmpty else { return }
        try? await CSSearchableIndex.default().deleteAppEntities(identifiedBy: ids, ofType: type)
    }
}

/// Lightweight existential so the generic purge can read `lastSyncedAt` across
/// the cached model types without bespoke per-type code.
private protocol StaleDatable { var lastSyncedAt: Date { get } }
extension CachedEvent: StaleDatable {}
extension CachedBlock: StaleDatable {}
extension CachedPlace: StaleDatable {}
extension CachedMetric: StaleDatable {}
extension CachedMoneyAccount: StaleDatable {}
extension CachedAnomaly: StaleDatable {}
extension CachedDaySummary: StaleDatable {}

@MainActor
private extension CSSearchableIndex {
    /// Indexes a batch of entities, swallowing transient indexing errors (the
    /// nightly task re-runs and CoreSpotlight de-dupes by identifier).
    func indexEntities<E: IndexedEntity>(_ entities: [E]) async {
        guard !entities.isEmpty else { return }
        try? await indexAppEntities(entities)
    }

    func indexEntities<E: IndexedEntity>(_ entities: [E]) async throws -> Int {
        guard !entities.isEmpty else { return 0 }
        try await indexAppEntities(entities)
        return entities.count
    }
}
