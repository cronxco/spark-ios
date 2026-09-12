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

    private struct FilterKey: Equatable, Sendable {
        let scope: NotificationsEndpoint.Scope
        let stream: NotificationFeedItem.Stream?
        let search: String?

        var usesCache: Bool {
            scope == .active && stream == nil && search == nil
        }
    }

    private(set) var state: LoadState = .idle
    private(set) var items: [NotificationFeedItem] = []
    private(set) var counts = NotificationFeedCounts()
    private(set) var nextCursor: String?
    private(set) var isLoadingMore = false
    private(set) var isShowingCachedData = false

    private var filter = FilterKey(scope: .active, stream: nil, search: nil)
    private var requestGeneration = 0
    private var loadMoreGeneration: Int?

    private let apiClient: APIClient
    private let container: ModelContainer
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "Notifications")

    init(apiClient: APIClient, container: ModelContainer) {
        self.apiClient = apiClient
        self.container = container
    }

    var hasMore: Bool { nextCursor != nil }
    var hasUnread: Bool { items.contains { $0.kind == .notification && !$0.isRead } }

    func refresh(
        scope: NotificationsEndpoint.Scope = .active,
        stream: NotificationFeedItem.Stream? = nil,
        search: String? = nil
    ) async {
        let requestedFilter = FilterKey(
            scope: scope,
            stream: stream,
            search: search?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        let filterChanged = requestedFilter != filter
        filter = requestedFilter
        requestGeneration &+= 1
        let generation = requestGeneration

        if filterChanged {
            items = []
            nextCursor = nil
            isShowingCachedData = false
            isLoadingMore = false
            loadMoreGeneration = nil
        }

        if items.isEmpty && requestedFilter.usesCache {
            loadCached()
        }
        _ = await refreshReturningSuccess(filter: requestedFilter, generation: generation)
    }

    private func refreshReturningSuccess(filter: FilterKey, generation: Int) async -> Bool {
        if items.isEmpty { state = .loading }
        do {
            let page = try await apiClient.request(NotificationsEndpoint.feed(
                scope: filter.scope,
                stream: filter.stream,
                search: filter.search
            ))
            guard isCurrent(filter: filter, generation: generation) else { return false }
            items = page.data
            counts = page.counts
            nextCursor = page.nextCursor
            isShowingCachedData = false
            if filter.usesCache {
                persist(page.data, replaceAll: true)
            }
            state = .loaded
            return true
        } catch APIError.notModified {
            guard isCurrent(filter: filter, generation: generation) else { return false }
            isShowingCachedData = false
            state = .loaded
            return true
        } catch {
            guard isCurrent(filter: filter, generation: generation) else { return false }
            SparkObservability.captureHandled(error)
            logger.error("Notifications fetch failed: \(String(describing: error))")
            if !items.isEmpty {
                isShowingCachedData = true
                state = .loaded
            } else {
                state = .error("Spark couldn’t load notifications. Check your connection and try again.")
            }
            return false
        }
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        let requestedFilter = filter
        let generation = requestGeneration
        isLoadingMore = true
        loadMoreGeneration = generation
        defer {
            if loadMoreGeneration == generation {
                isLoadingMore = false
                loadMoreGeneration = nil
            }
        }
        do {
            let page = try await apiClient.request(NotificationsEndpoint.feed(
                scope: requestedFilter.scope,
                stream: requestedFilter.stream,
                search: requestedFilter.search,
                cursor: cursor
            ))
            guard isCurrent(filter: requestedFilter, generation: generation) else { return }
            items.append(contentsOf: page.data)
            counts = page.counts
            nextCursor = page.nextCursor
            if requestedFilter.usesCache {
                persist(page.data, replaceAll: false)
            }
        } catch {
            guard isCurrent(filter: requestedFilter, generation: generation) else { return }
            SparkObservability.captureHandled(error)
            logger.error("Notifications load-more failed: \(String(describing: error))")
        }
    }

    func markRead(_ id: String) async {
        await setRead(id, isRead: true)
    }

    func markUnread(_ id: String) async {
        await setRead(id, isRead: false)
    }

    private func setRead(_ id: String, isRead: Bool) async {
        guard let index = items.firstIndex(where: { $0.id == id && $0.kind == .notification }) else { return }
        let actionFilter = filter
        let generation = requestGeneration
        let previous = items[index].isRead
        let previousCounts = counts
        guard previous != isRead else { return }
        items[index].isRead = isRead
        if actionFilter.scope == .active {
            updateCounts(unreadDelta: isRead ? -1 : 1)
        }

        do {
            let endpoint = isRead
                ? NotificationsEndpoint.markRead(id: id)
                : NotificationsEndpoint.markUnread(id: id)
            _ = try await apiClient.request(endpoint)
            updateReadFlag(id: id, isRead: isRead)
            await refreshCurrentFilter()
        } catch {
            if isCurrent(filter: actionFilter, generation: generation),
               let current = items.firstIndex(where: { $0.id == id }) {
                items[current].isRead = previous
                counts = previousCounts
            }
            SparkObservability.captureHandled(error)
            logger.error("Updating notification read state failed: \(String(describing: error))")
        }
    }

    func markAllRead() async {
        let actionFilter = filter
        let generation = requestGeneration
        let previous = items
        let previousCounts = counts
        for index in items.indices where items[index].kind == .notification {
            items[index].isRead = true
        }
        counts = NotificationFeedCounts(
            unread: 0,
            unresolvedAttention: counts.unresolvedAttention,
            activeActivity: counts.activeActivity,
            byStream: counts.byStream
        )
        do {
            _ = try await apiClient.request(NotificationsEndpoint.markAllRead())
            updateAllReadFlag(isRead: true)
            await refreshCurrentFilter()
        } catch {
            if isCurrent(filter: actionFilter, generation: generation) {
                items = previous
                counts = previousCounts
            }
            SparkObservability.captureHandled(error)
            logger.error("markAllRead failed: \(String(describing: error))")
        }
    }

    func archive(_ id: String) async {
        guard let index = items.firstIndex(where: { $0.id == id && $0.kind == .notification }) else { return }
        let actionFilter = filter
        let generation = requestGeneration
        let previousCounts = counts
        let removed = items.remove(at: index)
        if actionFilter.scope == .active {
            updateCounts(
                unreadDelta: removed.isRead ? 0 : -1,
                attentionDelta: removed.stream == .attention ? -1 : 0,
                removedFrom: removed.stream
            )
        }
        do {
            _ = try await apiClient.request(NotificationsEndpoint.archive(id: id))
            removeCached(id: id)
            await refreshCurrentFilter()
        } catch {
            if isCurrent(filter: actionFilter, generation: generation) {
                items.insert(removed, at: min(index, items.endIndex))
                counts = previousCounts
            }
            SparkObservability.captureHandled(error)
            logger.error("archive failed: \(String(describing: error))")
        }
    }

    private func refreshCurrentFilter() async {
        let currentFilter = filter
        await refresh(
            scope: currentFilter.scope,
            stream: currentFilter.stream,
            search: currentFilter.search
        )
    }

    private func isCurrent(filter: FilterKey, generation: Int) -> Bool {
        self.filter == filter && requestGeneration == generation
    }

    private func updateCounts(
        unreadDelta: Int = 0,
        attentionDelta: Int = 0,
        removedFrom stream: NotificationFeedItem.Stream? = nil
    ) {
        var byStream = counts.byStream
        if let stream {
            byStream[stream.rawValue] = max(0, (byStream[stream.rawValue] ?? 0) - 1)
        }
        counts = NotificationFeedCounts(
            unread: max(0, counts.unread + unreadDelta),
            unresolvedAttention: max(0, counts.unresolvedAttention + attentionDelta),
            activeActivity: counts.activeActivity,
            byStream: byStream
        )
    }

    // MARK: - Existing lightweight cache

    private func loadCached() {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CachedNotification>(sortBy: [SortDescriptor(\.receivedAt, order: .reverse)])
        descriptor.fetchLimit = 50
        guard let rows = try? context.fetch(descriptor), !rows.isEmpty else { return }

        items = rows.map { row in
            NotificationFeedItem(
                id: row.id,
                stream: NotificationFeedItem.Stream(rawValue: row.domain ?? "") ?? .updates,
                title: row.title,
                body: row.body,
                isRead: row.isRead,
                occurredAt: row.receivedAt,
                entity: entity(from: row)
            )
        }
        counts = NotificationFeedCounts(unread: rows.count { !$0.isRead })
        isShowingCachedData = true
        state = .loaded
    }

    private func entity(from row: CachedNotification) -> NotificationItem.EntityRef? {
        guard
            let rawKind = row.entityKind,
            let kind = NotificationItem.EntityKind(rawValue: rawKind),
            let id = row.entityId
        else { return nil }
        return .init(kind: kind, id: id)
    }

    private func persist(_ items: [NotificationFeedItem], replaceAll: Bool) {
        let context = ModelContext(container)
        if replaceAll, let existing = try? context.fetch(FetchDescriptor<CachedNotification>()) {
            for item in existing { context.delete(item) }
        }
        for item in items where item.kind == .notification {
            let itemID = item.id
            let descriptor = FetchDescriptor<CachedNotification>(predicate: #Predicate { $0.id == itemID })
            if let existing = (try? context.fetch(descriptor))?.first {
                existing.title = item.title
                existing.body = item.body
                existing.domain = item.stream.rawValue
                existing.isRead = item.isRead
                existing.receivedAt = item.occurredAt
                existing.entityKind = item.entity?.kind.rawValue
                existing.entityId = item.entity?.id
                existing.lastSyncedAt = .now
            } else {
                context.insert(CachedNotification(
                    id: item.id,
                    title: item.title,
                    body: item.body,
                    domain: item.stream.rawValue,
                    isRead: item.isRead,
                    receivedAt: item.occurredAt,
                    entityKind: item.entity?.kind.rawValue,
                    entityId: item.entity?.id
                ))
            }
        }
        try? context.save()
    }

    private func updateReadFlag(id: String, isRead: Bool) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedNotification>(predicate: #Predicate { $0.id == id })
        if let row = (try? context.fetch(descriptor))?.first {
            row.isRead = isRead
            try? context.save()
        }
    }

    private func updateAllReadFlag(isRead: Bool) {
        let context = ModelContext(container)
        if let rows = try? context.fetch(FetchDescriptor<CachedNotification>()) {
            for row in rows { row.isRead = isRead }
            try? context.save()
        }
    }

    private func removeCached(id: String) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedNotification>(predicate: #Predicate { $0.id == id })
        if let row = (try? context.fetch(descriptor))?.first {
            context.delete(row)
            try? context.save()
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
