import Foundation
import Observation
import SparkKit
import SwiftData

enum TodayNetworkState: Equatable {
    case idle
    case loading
    case error(String)
}

@MainActor
@Observable
final class TodayViewModel {
    let date: Date
    private(set) var cached: DaySummary?
    private(set) var networkState: TodayNetworkState = .idle

    private let apiClient: APIClient
    private let container: ModelContainer

    init(date: Date, apiClient: APIClient, container: ModelContainer) {
        self.date = date
        self.apiClient = apiClient
        self.container = container
    }

    func load() async {
        loadCached()
        await revalidate()
        await loadFeed()
    }

    func refresh() async {
        await revalidate(force: true)
    }

    private func loadCached() {
        let key = Self.isoKey(for: date)
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedDaySummary>(predicate: #Predicate { $0.date == key })
        if let cached = try? context.fetch(descriptor).first,
           let decoded = try? cached.decoded() {
            self.cached = decoded
        }
    }

    private func revalidate(force: Bool = false) async {
        networkState = .loading
        do {
            let summary = try await apiClient.request(
                BriefingEndpoint.today(date: Self.isoKey(for: date))
            )
            cached = summary
            try await persist(summary)
            networkState = .idle
        } catch APIError.notModified {
            networkState = .idle
        } catch APIError.transport(let underlying)
            where (underlying as? URLError)?.code == .cancelled {
            // Task cancelled (e.g. page swiped away) — not a user-visible error
            networkState = .idle
        } catch is CancellationError {
            networkState = .idle
        } catch {
            SparkObservability.captureHandled(error)
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            networkState = force ? .error(message) : (cached == nil ? .error(message) : .idle)
        }
    }

    private func loadFeed() async {
        do {
            var cursor: String?
            let dateKey = Self.isoKey(for: date)
            let context = ModelContext(container)

            repeat {
                let page = try await apiClient.request(FeedEndpoint.feed(cursor: cursor, limit: 100, date: dateKey))
                for event in page.data {
                    upsert(event, in: context)
                }
                cursor = page.hasMore ? page.nextCursor : nil
            } while cursor != nil

            try? context.save()
        } catch APIError.notModified {
            // feed unchanged — no action needed
        } catch is CancellationError {
        } catch APIError.transport(let underlying)
            where (underlying as? URLError)?.code == .cancelled {
        } catch { /* non-fatal */ }
    }

    private func upsert(_ event: Event, in context: ModelContext) {
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
            existing.displayName = event.displayName
            existing.hidden = event.hidden
            existing.displayValue = event.displayValue
            existing.tagNames = CachedEvent.encodeTagNames(event.tags)
            existing.blocksCount = event.blocksCount
            existing.actorTitle = event.actor?.title
            existing.actorType = event.actor?.type
            existing.actorMediaUrl = event.actor?.mediaUrl
            existing.targetTitle = event.target?.title
            existing.targetType = event.target?.type
            existing.targetMediaUrl = event.target?.mediaUrl
            existing.lastSyncedAt = .now
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
                displayName: event.displayName,
                hidden: event.hidden,
                displayValue: event.displayValue,
                tagNames: CachedEvent.encodeTagNames(event.tags),
                blocksCount: event.blocksCount,
                actorTitle: event.actor?.title,
                actorType: event.actor?.type,
                actorMediaUrl: event.actor?.mediaUrl,
                targetTitle: event.target?.title,
                targetType: event.target?.type,
                targetMediaUrl: event.target?.mediaUrl
            ))
        }
    }

    private func persist(_ summary: DaySummary) async throws {
        let context = ModelContext(container)
        let data = try JSONEncoder().encode(summary)
        let key = Self.isoKey(for: date)

        let descriptor = FetchDescriptor<CachedDaySummary>(predicate: #Predicate { $0.date == key })
        if let existing = try context.fetch(descriptor).first {
            existing.payload = data
            existing.timezone = summary.timezone
            existing.lastSyncedAt = .now
        } else {
            context.insert(CachedDaySummary(
                date: key,
                timezone: summary.timezone,
                payload: data,
                lastSyncedAt: .now
            ))
        }
        try context.save()
    }

    static func isoKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
