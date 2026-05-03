import Foundation
import OSLog
import SparkKit
import SwiftData

/// Fetches the /sync/delta endpoint and applies the response to SwiftData.
///
/// All SwiftData operations run on the MainActor so the ModelContext is
/// never accessed across thread-suspension points.
public enum DeltaSyncer {
    private static let logger = Logger(subsystem: "co.cronx.spark", category: "DeltaSyncer")

    /// Fetches new events from the server and applies them to the local cache.
    /// Returns `true` if any records were written, `false` for no-change or error.
    @MainActor
    public static func sync(using apiClient: APIClient, container: ModelContainer) async -> Bool {
        let context = ModelContext(container)
        let cursor = readCursor(resource: "events", from: context)

        do {
            let delta = try await apiClient.request(SyncEndpoint.delta(since: cursor))
            let created = delta.created.count
            let updated = delta.updated.count
            let deleted = delta.deleted.count
            applyDelta(delta, to: context)
            try context.save()
            logger.info("Delta sync: +\(created, privacy: .public) ~\(updated, privacy: .public) -\(deleted, privacy: .public) cursor=\(delta.nextCursor, privacy: .public)")
            return created > 0 || updated > 0 || deleted > 0
        } catch APIError.notModified {
            return false
        } catch {
            logger.error("Delta sync error: \(error, privacy: .public)")
            return false
        }
    }

    // MARK: - Private

    private static func readCursor(resource: String, from context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<SyncCursor>(
            predicate: #Predicate { $0.resource == resource }
        )
        return (try? context.fetch(descriptor))?.first?.cursor
    }

    private static func applyDelta(_ delta: SyncEndpoint.DeltaResponse, to context: ModelContext) {
        let now = Date.now

        for event in delta.created + delta.updated {
            upsertEvent(event, in: context, syncedAt: now)
        }
        for id in delta.deleted {
            deleteEvent(id: id, from: context)
        }
        saveNextCursor(delta.nextCursor, resource: "events", in: context)
    }

    private static func upsertEvent(_ event: Event, in context: ModelContext, syncedAt: Date) {
        let eventId = event.id
        let descriptor = FetchDescriptor<CachedEvent>(
            predicate: #Predicate { $0.id == eventId }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.time = event.time
            existing.service = event.service
            existing.domain = event.domain
            existing.action = event.action
            existing.value = event.value
            existing.unit = event.unit
            existing.url = event.url
            existing.actorTitle = event.actor?.title
            existing.targetTitle = event.target?.title
            existing.lastSyncedAt = syncedAt
        } else {
            context.insert(CachedEvent(
                id: event.id,
                time: event.time,
                service: event.service,
                domain: event.domain,
                action: event.action,
                value: event.value,
                unit: event.unit,
                url: event.url,
                actorTitle: event.actor?.title,
                targetTitle: event.target?.title,
                lastSyncedAt: syncedAt
            ))
        }
    }

    private static func deleteEvent(id: String, from context: ModelContext) {
        let descriptor = FetchDescriptor<CachedEvent>(
            predicate: #Predicate { $0.id == id }
        )
        if let cached = (try? context.fetch(descriptor))?.first {
            context.delete(cached)
        }
    }

    private static func saveNextCursor(_ cursor: String, resource: String, in context: ModelContext) {
        let descriptor = FetchDescriptor<SyncCursor>(
            predicate: #Predicate { $0.resource == resource }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.cursor = cursor
            existing.lastSyncedAt = .now
        } else {
            context.insert(SyncCursor(resource: resource, cursor: cursor, lastSyncedAt: .now))
        }
    }
}
