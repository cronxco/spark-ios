import Foundation
import Observation
import OSLog
import SparkKit
import SwiftData

@MainActor
@Observable
final class NotificationsInboxViewModel {
    enum LoadState: Sendable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    private(set) var state: LoadState = .idle
    private(set) var items: [NotificationItem] = []
    private(set) var nextCursor: String?
    private(set) var isLoadingMore = false

    private let apiClient: APIClient
    private let container: ModelContainer
    private let logger = Logger(subsystem: "co.cronx.spark", category: "Notifications")

    init(apiClient: APIClient, container: ModelContainer) {
        self.apiClient = apiClient
        self.container = container
    }

    var hasMore: Bool { nextCursor != nil }

    func refresh() async {
        state = .loading
        do {
            let page = try await apiClient.request(NotificationsEndpoint.list())
            items = page.data
            nextCursor = page.nextCursor
            await persist(page.data, replaceAll: true)
            state = .loaded
        } catch APIError.notModified {
            state = .loaded
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Notifications fetch failed: \(String(describing: error))")
            state = .error("Couldn't load notifications.")
        }
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await apiClient.request(NotificationsEndpoint.list(cursor: cursor))
            items.append(contentsOf: page.data)
            nextCursor = page.nextCursor
            await persist(page.data, replaceAll: false)
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Notifications load-more failed: \(String(describing: error))")
        }
    }

    func markRead(_ id: String) async {
        // Optimistic update.
        if let index = items.firstIndex(where: { $0.id == id }), !items[index].isRead {
            items[index] = NotificationItem(
                id: items[index].id,
                title: items[index].title,
                body: items[index].body,
                domain: items[index].domain,
                isRead: true,
                receivedAt: items[index].receivedAt,
                entity: items[index].entity
            )
        }
        do {
            _ = try await apiClient.request(NotificationsEndpoint.markRead(id: id))
            await updateReadFlag(id: id, isRead: true)
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("markRead failed: \(String(describing: error))")
        }
    }

    func markAllRead() async {
        for index in items.indices where !items[index].isRead {
            items[index] = NotificationItem(
                id: items[index].id,
                title: items[index].title,
                body: items[index].body,
                domain: items[index].domain,
                isRead: true,
                receivedAt: items[index].receivedAt,
                entity: items[index].entity
            )
        }
        do {
            _ = try await apiClient.request(NotificationsEndpoint.markAllRead())
            await updateAllReadFlag(isRead: true)
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("markAllRead failed: \(String(describing: error))")
        }
    }

    func delete(_ id: String) async {
        items.removeAll { $0.id == id }
        do {
            _ = try await apiClient.request(NotificationsEndpoint.delete(id: id))
            await removeCached(id: id)
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("delete failed: \(String(describing: error))")
        }
    }

    // MARK: - Persistence

    private func persist(_ items: [NotificationItem], replaceAll: Bool) async {
        let context = ModelContext(container)
        if replaceAll {
            let descriptor = FetchDescriptor<CachedNotification>()
            if let existing = try? context.fetch(descriptor) {
                for item in existing {
                    context.delete(item)
                }
            }
        }
        for item in items {
            let cached = CachedNotification(
                id: item.id,
                title: item.title,
                body: item.body,
                domain: item.domain,
                isRead: item.isRead,
                receivedAt: item.receivedAt,
                entityKind: item.entity?.kind.rawValue,
                entityId: item.entity?.id
            )
            context.insert(cached)
        }
        try? context.save()
    }

    private func updateReadFlag(id: String, isRead: Bool) async {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedNotification>(predicate: #Predicate { $0.id == id })
        if let row = (try? context.fetch(descriptor))?.first {
            row.isRead = isRead
            try? context.save()
        }
    }

    private func updateAllReadFlag(isRead: Bool) async {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedNotification>()
        if let rows = try? context.fetch(descriptor) {
            for row in rows { row.isRead = isRead }
            try? context.save()
        }
    }

    private func removeCached(id: String) async {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedNotification>(predicate: #Predicate { $0.id == id })
        if let row = (try? context.fetch(descriptor))?.first {
            context.delete(row)
            try? context.save()
        }
    }
}
