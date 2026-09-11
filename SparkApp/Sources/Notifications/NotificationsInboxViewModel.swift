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
    private(set) var items: [NotificationFeedItem] = []
    private(set) var counts = NotificationFeedCounts()
    private(set) var nextCursor: String?
    private(set) var isLoadingMore = false
    private(set) var isShowingCachedData = false

    private var scope: NotificationsEndpoint.Scope = .active
    private var stream: NotificationFeedItem.Stream?
    private var search: String?

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
        self.scope = scope
        self.stream = stream
        self.search = search?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        if items.isEmpty && scope == .active && stream == nil && self.search == nil {
            loadCached()
        }
        _ = await refreshReturningSuccess()
    }

    private func refreshReturningSuccess() async -> Bool {
        if items.isEmpty { state = .loading }
        do {
            let page = try await apiClient.request(NotificationsEndpoint.feed(
                scope: scope,
                stream: stream,
                search: search
            ))
            items = page.data
            counts = page.counts
            nextCursor = page.nextCursor
            isShowingCachedData = false
            if scope == .active && stream == nil && search == nil {
                persist(page.data, replaceAll: true)
            }
            state = .loaded
            return true
        } catch APIError.notModified {
            state = .loaded
            return true
        } catch {
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
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await apiClient.request(NotificationsEndpoint.feed(
                scope: scope,
                stream: stream,
                search: search,
                cursor: cursor
            ))
            items.append(contentsOf: page.data)
            counts = page.counts
            nextCursor = page.nextCursor
            if scope == .active && stream == nil && search == nil {
                persist(page.data, replaceAll: false)
            }
        } catch {
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
        let previous = items[index].isRead
        guard previous != isRead else { return }
        items[index].isRead = isRead

        do {
            let endpoint = isRead
                ? NotificationsEndpoint.markRead(id: id)
                : NotificationsEndpoint.markUnread(id: id)
            _ = try await apiClient.request(endpoint)
            updateReadFlag(id: id, isRead: isRead)
        } catch {
            if let current = items.firstIndex(where: { $0.id == id }) {
                items[current].isRead = previous
            }
            SparkObservability.captureHandled(error)
            logger.error("Updating notification read state failed: \(String(describing: error))")
        }
    }

    func markAllRead() async {
        let previous = items
        for index in items.indices where items[index].kind == .notification {
            items[index].isRead = true
        }
        do {
            _ = try await apiClient.request(NotificationsEndpoint.markAllRead())
            updateAllReadFlag(isRead: true)
        } catch {
            items = previous
            SparkObservability.captureHandled(error)
            logger.error("markAllRead failed: \(String(describing: error))")
        }
    }

    func archive(_ id: String) async {
        guard let index = items.firstIndex(where: { $0.id == id && $0.kind == .notification }) else { return }
        let removed = items.remove(at: index)
        do {
            _ = try await apiClient.request(NotificationsEndpoint.archive(id: id))
            removeCached(id: id)
        } catch {
            items.insert(removed, at: min(index, items.endIndex))
            SparkObservability.captureHandled(error)
            logger.error("archive failed: \(String(describing: error))")
        }
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
