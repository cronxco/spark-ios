import Foundation
import SwiftData
import Testing

@testable import Spark
@testable import SparkKit

@Suite("Account teardown and notification preferences", .serialized)
@MainActor
struct SignOutAndPreferencesTests {
    /// Own host: the stub is process-wide and suites run in parallel.
    private static let host = "signout.spark.test"

    private let environment = APIEnvironment(
        baseURL: URL(string: "https://signout.spark.test/api/v1/mobile")!,
        oauthAuthorizeURL: URL(string: "https://signout.spark.test/oauth/authorize")!,
        name: "test"
    )

    @Test("offline device revocation retries with the departing account authorization")
    func offlineRevocationRetriesOnForeground() async throws {
        let defaults = UserDefaults.sparkAppGroup
        defaults.removeObject(forKey: AppModel.pendingDeviceRevocationKey)
        defaults.set("device-1", forKey: "spark.apnsDeviceId")
        defer {
            defaults.removeObject(forKey: AppModel.pendingDeviceRevocationKey)
            defaults.removeObject(forKey: "spark.apnsDeviceId")
        }

        let tokenStore = makeTokenStore()
        try await tokenStore.store(access: "departing-user", refresh: "refresh", expiresIn: 3_600)
        let model = AppModel(
            container: try SparkDataStore.makeInMemoryContainer(),
            environment: environment,
            session: makeSession(),
            tokenStore: tokenStore,
            purgeSpotlight: {}
        )
        model.session = .loggedIn

        await AppStubURLProtocol.set(host: Self.host) { request in
            if request.url?.path.hasSuffix("/devices/device-1") == true {
                return (Data(), 503, [:])
            }
            return (Data(), 204, [:])
        }

        await model.signOut()

        #expect(model.session == .loggedIn)
        #expect(await tokenStore.accessToken() == "departing-user")
        #expect(defaults.string(forKey: AppModel.pendingDeviceRevocationKey) == "device-1")

        await AppStubURLProtocol.set(host: Self.host) { _ in (Data(), 204, [:]) }
        await model.reverbConnect()

        #expect(model.session == .loggedOut)
        #expect(await tokenStore.accessToken() == nil)
        #expect(defaults.string(forKey: AppModel.pendingDeviceRevocationKey) == nil)
    }

    @Test("a failed cache purge blocks account transition until a retry erases notifications")
    func failedPurgeBlocksTransitionAndRetryErasesNotifications() async throws {
        let defaults = UserDefaults.sparkAppGroup
        defaults.removeObject(forKey: AppModel.pendingDeviceRevocationKey)
        defaults.removeObject(forKey: "spark.apnsDeviceId")
        defer {
            defaults.removeObject(forKey: AppModel.pendingDeviceRevocationKey)
            defaults.removeObject(forKey: "spark.apnsDeviceId")
        }

        let container = try SparkDataStore.makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(CachedNotification(id: "private", title: "Private", receivedAt: .now))
        try context.save()

        let model = AppModel(
            container: container,
            environment: environment,
            session: makeSession(),
            tokenStore: makeTokenStore(),
            purgeDataStore: { _ in throw ForcedPurgeError() },
            purgeSpotlight: {}
        )
        model.session = .loggedIn

        await model.signOut()

        #expect(model.session == .loggedIn)
        #expect(try context.fetch(FetchDescriptor<CachedNotification>()).count == 1)

        let retry = AppModel(
            container: container,
            environment: environment,
            session: makeSession(),
            tokenStore: makeTokenStore(),
            purgeSpotlight: {}
        )
        retry.session = .loggedIn
        await retry.signOut()

        #expect(retry.session == .loggedOut)
        #expect(try context.fetch(FetchDescriptor<CachedNotification>()).isEmpty)

        let nextAccount = AppModel(
            container: container,
            environment: environment,
            session: makeSession(),
            tokenStore: makeTokenStore(),
            purgeSpotlight: {}
        )
        nextAccount.session = .loggedIn
        #expect(try context.fetch(FetchDescriptor<CachedNotification>()).isEmpty)
    }

    @Test("PATCH adopts its response ETag for the next notification preference update")
    func preferencePatchAdvancesVersion() async throws {
        let tokenStore = makeTokenStore()
        try await tokenStore.store(access: "token", refresh: "refresh", expiresIn: 3_600)
        let client = APIClient(
            environment: environment,
            session: makeSession(),
            tokenStore: tokenStore,
            etagCache: makeETagCache()
        )
        let patchCount = PatchCounter()

        await AppStubURLProtocol.set(host: Self.host) { request in
            if request.httpMethod == "GET" {
                return (
                    Data(#"{"categories":{},"delivery_mode":"immediate"}"#.utf8),
                    200,
                    ["ETag": "\"v1\""]
                )
            }

            let count = await patchCount.increment()
            return (Data(), 204, ["ETag": count == 1 ? "\"v2\"" : "\"v3\""])
        }

        let viewModel = NotificationsPreferencesViewModel(apiClient: client)
        await viewModel.load()
        viewModel.scheduleUpdate(NotificationPreferences(deliveryMode: .immediate))
        try await waitForSaveStatus(.saved, on: viewModel)
        viewModel.scheduleUpdate(NotificationPreferences(deliveryMode: .workHours))
        try await waitForPatchCount(2)

        let patches = (await AppStubURLProtocol.recorded(host: Self.host)).filter { $0.httpMethod == "PATCH" }
        #expect(patches.count == 2)
        #expect(patches.first?.value(forHTTPHeaderField: "If-Match") == "\"v1\"")
        #expect(patches.last?.value(forHTTPHeaderField: "If-Match") == "\"v2\"")
    }

    @Test("a failed archive restores the optimistically removed notification")
    func failedArchiveRestoresNotification() async throws {
        let tokenStore = makeTokenStore()
        try await tokenStore.store(access: "token", refresh: "refresh", expiresIn: 3_600)
        let client = APIClient(
            environment: environment,
            session: makeSession(),
            tokenStore: tokenStore,
            etagCache: makeETagCache()
        )
        let requestCount = RequestCounter()

        await AppStubURLProtocol.set(host: Self.host) { request in
            let count = await requestCount.increment()
            if count == 1 {
                let page = #"{"data":[{"contract_version":1,"id":"notification-1","kind":"notification","type":"daily_digest","stream":"updates","severity":"info","state":"active","title":"Private","body":null,"is_read":false,"occurrence_count":1,"occurred_at":"2026-09-06T12:00:00Z","updated_at":"2026-09-06T12:00:00Z","archived_at":null,"entity":null,"destination":null,"primary_action":null,"progress":null,"has_technical_detail":false,"version":"\"v1\""}],"next_cursor":null,"has_more":false,"counts":{"unread":1,"unresolved_attention":0,"active_activity":0,"by_stream":{"updates":1,"activity":0,"attention":0,"system":0}}}"#
                return (Data(page.utf8), 200, [:])
            }
            if request.httpMethod == "POST" {
                return (Data(), 412, [:])
            }
            return (Data(), 500, [:])
        }

        let viewModel = NotificationsInboxViewModel(
            apiClient: client,
            container: try SparkDataStore.makeInMemoryContainer()
        )
        await viewModel.refresh()
        await viewModel.archive("notification-1")

        #expect(viewModel.items.map(\.id) == ["notification-1"])
        #expect(viewModel.counts.unread == 1)
    }

    @Test("a stale response cannot replace a newer notification filter")
    func staleNotificationResponseIsDiscarded() async throws {
        let tokenStore = makeTokenStore()
        try await tokenStore.store(access: "token", refresh: "refresh", expiresIn: 3_600)
        let client = APIClient(
            environment: environment,
            session: makeSession(),
            tokenStore: tokenStore,
            etagCache: makeETagCache()
        )
        let gate = ResponseGate()
        let activeData = try feedData(
            items: [NotificationFeedItem(id: "active", title: "Active")],
            nextCursor: "active-next",
            counts: NotificationFeedCounts(unread: 1)
        )
        let historyData = try feedData(
            items: [NotificationFeedItem(id: "history", state: .archived, title: "History")],
            counts: NotificationFeedCounts()
        )

        await AppStubURLProtocol.set(host: Self.host) { request in
            let scope = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "scope" })?
                .value
            if scope == NotificationsEndpoint.Scope.active.rawValue {
                await gate.wait()
                return (activeData, 200, [:])
            }
            return (historyData, 200, [:])
        }

        let viewModel = NotificationsInboxViewModel(
            apiClient: client,
            container: try SparkDataStore.makeInMemoryContainer()
        )
        let activeRefresh = Task { await viewModel.refresh(scope: .active) }
        try await waitForRequestCount(1)
        await viewModel.refresh(scope: .history)
        await gate.release()
        await activeRefresh.value

        #expect(viewModel.items.map(\.id) == ["history"])
        #expect(!viewModel.hasMore)
        #expect(!viewModel.isShowingCachedData)
    }

    @Test("successful notification actions keep feed counts current")
    func successfulNotificationActionsRefreshCounts() async throws {
        let tokenStore = makeTokenStore()
        try await tokenStore.store(access: "token", refresh: "refresh", expiresIn: 3_600)
        let client = APIClient(
            environment: environment,
            session: makeSession(),
            tokenStore: tokenStore,
            etagCache: makeETagCache()
        )
        let requestCount = RequestCounter()
        let attentionUnread = NotificationFeedItem(
            id: "attention",
            stream: .attention,
            severity: .warning,
            title: "Needs attention"
        )
        let updatesUnread = NotificationFeedItem(id: "update", stream: .updates, title: "Update")
        var attentionRead = attentionUnread
        attentionRead.isRead = true
        var updatesRead = updatesUnread
        updatesRead.isRead = true

        let initial = try feedData(
            items: [attentionUnread, updatesUnread],
            counts: NotificationFeedCounts(
                unread: 2,
                unresolvedAttention: 1,
                byStream: ["attention": 1, "updates": 1]
            )
        )
        let afterRead = try feedData(
            items: [attentionRead, updatesUnread],
            counts: NotificationFeedCounts(
                unread: 1,
                unresolvedAttention: 1,
                byStream: ["attention": 1, "updates": 1]
            )
        )
        let afterReadAll = try feedData(
            items: [attentionRead, updatesRead],
            counts: NotificationFeedCounts(
                unread: 0,
                unresolvedAttention: 1,
                byStream: ["attention": 1, "updates": 1]
            )
        )
        let afterArchive = try feedData(
            items: [updatesRead],
            counts: NotificationFeedCounts(
                unread: 0,
                unresolvedAttention: 0,
                byStream: ["attention": 0, "updates": 1]
            )
        )

        await AppStubURLProtocol.set(host: Self.host) { _ in
            switch await requestCount.increment() {
            case 1: (initial, 200, [:])
            case 2, 4, 6: (Data(), 204, [:])
            case 3: (afterRead, 200, [:])
            case 5: (afterReadAll, 200, [:])
            case 7: (afterArchive, 200, [:])
            default: (Data(), 500, [:])
            }
        }

        let viewModel = NotificationsInboxViewModel(
            apiClient: client,
            container: try SparkDataStore.makeInMemoryContainer()
        )
        await viewModel.refresh()
        await viewModel.markRead("attention")
        #expect(viewModel.counts.unread == 1)
        #expect(viewModel.counts.unresolvedAttention == 1)

        await viewModel.markAllRead()
        #expect(viewModel.counts.unread == 0)

        await viewModel.archive("attention")
        #expect(viewModel.counts.unresolvedAttention == 0)
        #expect(viewModel.counts.byStream["attention"] == 0)
        #expect(viewModel.items.map(\.id) == ["update"])
    }

    @Test("a 304 response clears the saved notification banner")
    func notModifiedClearsCachedDataBanner() async throws {
        let tokenStore = makeTokenStore()
        try await tokenStore.store(access: "token", refresh: "refresh", expiresIn: 3_600)
        let client = APIClient(
            environment: environment,
            session: makeSession(),
            tokenStore: tokenStore,
            etagCache: makeETagCache()
        )
        let container = try SparkDataStore.makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(CachedNotification(id: "cached", title: "Cached", receivedAt: .now))
        try context.save()
        await AppStubURLProtocol.set(host: Self.host) { _ in (Data(), 304, [:]) }

        let viewModel = NotificationsInboxViewModel(apiClient: client, container: container)
        await viewModel.refresh()

        #expect(viewModel.items.map(\.id) == ["cached"])
        #expect(!viewModel.isShowingCachedData)
    }

    private func makeTokenStore() -> KeychainTokenStore {
        KeychainTokenStore(
            service: "co.cronx.sparkapp.tests.signout.\(UUID().uuidString)",
            account: "test",
            accessGroup: nil
        )
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeETagCache() -> ETagCache {
        let suite = "spark.etag.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ETagCache(defaults: defaults)
    }

    private func feedData(
        items: [NotificationFeedItem],
        nextCursor: String? = nil,
        counts: NotificationFeedCounts
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(NotificationFeedPage(
            data: items,
            nextCursor: nextCursor,
            hasMore: nextCursor != nil,
            counts: counts
        ))
    }

    private func waitForRequestCount(_ expected: Int) async throws {
        for _ in 0..<40 {
            if await AppStubURLProtocol.recorded(host: Self.host).count >= expected { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        Issue.record("Timed out waiting for request \(expected)")
    }

    private func waitForPatchCount(_ expected: Int) async throws {
        for _ in 0..<40 {
            let count = (await AppStubURLProtocol.recorded(host: Self.host)).filter { $0.httpMethod == "PATCH" }.count
            if count >= expected { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("Timed out waiting for PATCH request \(expected)")
    }

    private func waitForSaveStatus(
        _ expected: NotificationsPreferencesViewModel.SaveStatus,
        on viewModel: NotificationsPreferencesViewModel
    ) async throws {
        for _ in 0..<60 {
            if viewModel.saveStatus == expected { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("Timed out waiting for save status \(expected)")
    }
}

private struct ForcedPurgeError: Error {}

private actor PatchCounter {
    private var count = 0

    func increment() -> Int {
        count += 1
        return count
    }
}

private actor RequestCounter {
    private var count = 0

    func increment() -> Int {
        count += 1
        return count
    }
}
private actor ResponseGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}
