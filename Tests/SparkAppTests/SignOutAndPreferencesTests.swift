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
        try await waitForPatchCount(1)
        viewModel.scheduleUpdate(NotificationPreferences(deliveryMode: .workHours))
        try await waitForPatchCount(2)

        let patches = (await AppStubURLProtocol.recorded(host: Self.host)).filter { $0.httpMethod == "PATCH" }
        #expect(patches.count == 2)
        #expect(patches.first?.value(forHTTPHeaderField: "If-Match") == "\"v1\"")
        #expect(patches.last?.value(forHTTPHeaderField: "If-Match") == "\"v2\"")
    }

    @Test("a failed conflict refresh restores the optimistically deleted notification")
    func failedConflictRefreshRestoresNotification() async throws {
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
                let page = #"{"data":[{"id":"notification-1","title":"Private","body":null,"domain":"money","is_read":false,"received_at":"2026-09-06T12:00:00Z","entity":null,"version":"\"v1\""}],"next_cursor":null,"has_more":false}"#
                return (Data(page.utf8), 200, [:])
            }
            if request.httpMethod == "DELETE" {
                return (Data(), 412, [:])
            }
            return (Data(), 500, [:])
        }

        let viewModel = NotificationsInboxViewModel(
            apiClient: client,
            container: try SparkDataStore.makeInMemoryContainer()
        )
        await viewModel.refresh()
        await viewModel.delete("notification-1")

        #expect(viewModel.items.map(\.id) == ["notification-1"])
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

    private func waitForPatchCount(_ expected: Int) async throws {
        for _ in 0..<40 {
            let count = (await AppStubURLProtocol.recorded(host: Self.host)).filter { $0.httpMethod == "PATCH" }.count
            if count >= expected { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("Timed out waiting for PATCH request \(expected)")
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
