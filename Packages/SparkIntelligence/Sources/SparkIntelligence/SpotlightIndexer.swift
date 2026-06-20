import AppIntents
import CoreSpotlight
import Foundation
import SparkKit
import SwiftData

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
        // Honour auth state: never index personal data while signed out.
        guard KeychainTokenStore().accessToken() != nil else { return }

        let index = CSSearchableIndex.default()

        await index.indexEntities(IntentService.eventEntities(matching: nil, limit: 1000))
        await index.indexEntities(IntentService.blockEntities(matching: nil, limit: 1000))
        await index.indexEntities(IntentService.placeEntities(matching: nil, limit: 1000))
        await index.indexEntities(IntentService.integrationEntities())
        await index.indexEntities(IntentService.metricEntities(matching: nil, limit: 1000))
        await index.indexEntities(IntentService.anomalyEntities(matching: nil, limit: 1000))
        await index.indexEntities(IntentService.daySummaryEntities(matching: nil, limit: 90))
    }

    // MARK: - Purge

    @MainActor
    public static func purgeStaleItems(container: ModelContainer) async {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -ttlDays, to: .now) else { return }
        let context = ModelContext(container)

        // Signed out: drop everything Spark contributed to the index.
        guard KeychainTokenStore().accessToken() != nil else {
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

        let staleAnomalies = fetchStale(CachedAnomaly.self, before: cutoff, in: context)
        await delete(AnomalyEntity.self, ids: staleAnomalies.map(\.id))

        let staleSummaries = fetchStale(CachedDaySummary.self, before: cutoff, in: context)
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

    private static func delete<E: IndexedEntity>(_ type: E.Type, ids: [String]) async {
        guard !ids.isEmpty else { return }
        try? await CSSearchableIndex.default().deleteAppEntities(identifiers: ids, ofType: type)
    }
}

/// Lightweight existential so the generic purge can read `lastSyncedAt` across
/// the cached model types without bespoke per-type code.
private protocol StaleDatable { var lastSyncedAt: Date { get } }
extension CachedEvent: StaleDatable {}
extension CachedBlock: StaleDatable {}
extension CachedPlace: StaleDatable {}
extension CachedMetric: StaleDatable {}
extension CachedAnomaly: StaleDatable {}
extension CachedDaySummary: StaleDatable {}

private extension CSSearchableIndex {
    /// Indexes a batch of entities, swallowing transient indexing errors (the
    /// nightly task re-runs and CoreSpotlight de-dupes by identifier).
    func indexEntities<E: IndexedEntity>(_ entities: [E]) async {
        guard !entities.isEmpty else { return }
        try? await indexAppEntities(entities)
    }
}
