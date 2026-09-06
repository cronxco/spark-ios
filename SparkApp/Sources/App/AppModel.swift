import Foundation
import Observation
import Sentry
import SparkHealth
import SparkIntelligence
import SparkKit
import SparkSync
import SwiftData
import UserNotifications
import WidgetKit

enum SessionState: Equatable {
    case unknown
    case loggedOut
    case loggedIn
}

enum AppRoute: Hashable {
    case today(date: Date?)
    case day(Date)
    case event(id: String)
    case object(id: String)
    case block(id: String)
    case metric(identifier: String)
    case place(id: String)
    case anomaly(id: String)
    case integration(service: String)
    case account(id: String)
    case tag(name: String, type: String?)
}

@MainActor
@Observable
final class AppModel {
    static let shared: AppModel = {
        // `AppModel.shared` throws in a non-runtime context would be worse than
        // falling back to an in-memory container — the container only matters
        // on a real device where the App Group is reachable. Simulator test
        // runs without entitlements should still render.
        let container: ModelContainer
        do {
            container = try SparkDataStore.makeContainer()
        } catch {
            container = (try? SparkDataStore.makeInMemoryContainer()) ?? {
                fatalError("Unable to bootstrap any SwiftData container: \(error)")
            }()
        }
        return AppModel(container: container)
    }()

    let container: ModelContainer
    let tokenStore: KeychainTokenStore
    let etagCache: ETagCache
    let apiClient: APIClient
    let authService: AuthenticationService
    let healthPermissions = HealthKitPermissionManager.shared
    let reverb: ReverbClient

    var session: SessionState = .unknown
    var onboardingComplete: Bool
    var lastError: String?
    var pendingRoute: AppRoute?
    private(set) var lastSyncAt: Date = .distantPast
    private(set) var profile: UserProfile? {
        didSet {
            if let name = profile?.name {
                UserDefaults.sparkAppGroup.set(name, forKey: "spark.profile.name")
            }
        }
    }
    private var deviceRegistrationTask: Task<Void, Never>?
    private var deviceRegistrationTokenInFlight: String?
    private let purgeDataStore: @MainActor (ModelContainer) throws -> Void
    private let purgeSpotlight: @MainActor () async throws -> Void

    init(
        container: ModelContainer,
        environment: APIEnvironment = .current(),
        session: URLSession = .shared,
        tokenStore: KeychainTokenStore = KeychainTokenStore(),
        etagCache: ETagCache = ETagCache(),
        purgeDataStore: @escaping @MainActor (ModelContainer) throws -> Void = { container in
            try SparkDataStore.purgeAll(in: container)
        },
        purgeSpotlight: @escaping @MainActor () async throws -> Void = {
            try await SpotlightIndexer.purgeAll()
        }
    ) {
        self.container = container
        let client = APIClient(
            environment: environment,
            session: session,
            tokenStore: tokenStore,
            etagCache: etagCache
        )
        self.tokenStore = tokenStore
        self.etagCache = etagCache
        self.apiClient = client
        self.authService = AuthenticationService(
            environment: environment,
            tokenStore: tokenStore,
            apiClient: client
        )
        self.reverb = ReverbClient(tokenStore: tokenStore)
        self.purgeDataStore = purgeDataStore
        self.purgeSpotlight = purgeSpotlight
        self.onboardingComplete = UserDefaults(suiteName: "group.co.cronx.sparkapp")?.bool(forKey: "onboarding.completed") == true
        if let cachedName = UserDefaults.sparkAppGroup.string(forKey: "spark.profile.name"), !cachedName.isEmpty {
            self.profile = UserProfile(id: "", name: cachedName, email: "")
        }
    }

    func bootstrap() async {
        clearLegacyCheckInKeysIfNeeded()
        if let token = await tokenStore.accessToken() {
            onboardingComplete = true
            session = .loggedIn
            if UserDefaults.sparkAppGroup.string(forKey: Self.pendingDeviceRevocationKey) != nil {
                await signOut()
                return
            }
            await registerDevice()
            await fetchAndCacheUserId()
            configureHealthUploader(accessToken: token)
            consumePendingIntentRoute()
            await wireReverbHandler()
            await reverbConnect()
        } else {
            session = .loggedOut
        }
    }

    private static let legacyCheckInMigrationKey = "spark.checkin.legacyCleared.v1"

    private func clearLegacyCheckInKeysIfNeeded() {
        let defaults = UserDefaults.sparkAppGroup
        guard !defaults.bool(forKey: Self.legacyCheckInMigrationKey) else { return }
        let legacyKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("checkin_") }
        for key in legacyKeys { defaults.removeObject(forKey: key) }
        defaults.set(true, forKey: Self.legacyCheckInMigrationKey)
    }

    private func wireReverbHandler() async {
        let client = apiClient
        let cont = container
        await reverb.addHandler { event in
            let syncEvents: Set<String> = [
                "event.created", "event.updated", "event.deleted",
                "anomaly.raised", "notification.received",
            ]
            guard syncEvents.contains(event.eventName) else { return }
            Task { @MainActor in
                let didSync = await DeltaSyncer.sync(using: client, container: cont)
                if didSync { self.lastSyncAt = .now }
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// Connect Reverb when the app is in the foreground.
    /// The user ID is cached in UserDefaults after bootstrap via GET /me.
    func reverbConnect() async {
        guard session == .loggedIn else { return }
        if UserDefaults.sparkAppGroup.string(forKey: Self.pendingDeviceRevocationKey) != nil {
            await signOut()
            return
        }
        let userId = UserDefaults.sparkAppGroup.string(forKey: "spark.userId") ?? ""
        guard !userId.isEmpty else { return }
        await reverb.connect(userId: userId)
    }

    /// Disconnect Reverb when the app moves to the background.
    func reverbDisconnect() async {
        await reverb.disconnect()
    }

    /// Parse a `kind:id` route string into an `AppRoute`.
    ///
    /// Shared by the AppIntent hand-off and by notification taps so there is
    /// one vocabulary rather than two parsers that drift. Returns nil for
    /// kinds that are not navigation (`action`, `search`).
    static func route(from raw: String) -> AppRoute? {
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard let kind = parts.first else { return nil }

        switch kind {
        case "today": return .today(date: nil)
        case "event": return parts.count > 1 ? .event(id: parts[1]) : nil
        case "object": return parts.count > 1 ? .object(id: parts[1]) : nil
        case "block": return parts.count > 1 ? .block(id: parts[1]) : nil
        case "metric": return parts.count > 1 ? .metric(identifier: parts[1]) : nil
        case "place": return parts.count > 1 ? .place(id: parts[1]) : nil
        case "anomaly": return parts.count > 1 ? .anomaly(id: parts[1]) : nil
        case "integration": return parts.count > 1 ? .integration(service: parts[1]) : nil
        case "account": return parts.count > 1 ? .account(id: parts[1]) : nil
        default: return nil
        }
    }

    /// Read a route written by an AppIntent (from the extension process) and
    /// navigate to it. Consumed once to prevent stale navigation on re-launch.
    private func consumePendingIntentRoute() {
        let defaults = UserDefaults(suiteName: "group.co.cronx.sparkapp")
        guard let raw = defaults?.string(forKey: "spark.pendingRoute") else { return }
        defaults?.removeObject(forKey: "spark.pendingRoute")
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard let kind = parts.first else { return }

        if let route = Self.route(from: raw) {
            pendingRoute = route
            return
        }

        switch kind {
        case "search":  break   // SearchView picks up the query separately
        case "action":
            if parts.last == "startSleep" {
                Task { await LiveActivityManager.shared.startSleepActivity(bedtime: .now, targetWakeTime: nil) }
            } else if parts.last == "endSleep" {
                Task { await LiveActivityManager.shared.endSleepActivity(score: 0, durationMinutes: 0) }
            }
        default: break
        }
    }

    private func fetchAndCacheUserId() async {
        guard let fetched = try? await apiClient.request(MeEndpoint.get()) else { return }
        profile = fetched
        UserDefaults.sparkAppGroup.set(fetched.id, forKey: "spark.userId")
    }

    private func configureHealthUploader(accessToken: String) {
        HealthSampleUploader.shared.configure(
            environment: APIEnvironment.current(),
            accessToken: accessToken
        )
    }

    func registerDevice() async {
        guard session == .loggedIn, await tokenStore.accessToken() != nil else { return }

        while true {
            guard let apnsToken = UserDefaults.sparkAppGroup.string(forKey: "spark.apnsToken") else { return }

            if let deviceRegistrationTask {
                let tokenInFlight = deviceRegistrationTokenInFlight
                await deviceRegistrationTask.value
                if tokenInFlight == apnsToken {
                    return
                }
                continue
            }

            let task = Task { @MainActor [apiClient] in
            #if canImport(UIKit)
                let name = UIDevice.current.name
                let osVersion = UIDevice.current.systemVersion
            #else
                let name = "Unknown"
                let osVersion = "Unknown"
            #endif

                let info = Bundle.main.infoDictionary
                let appVersion = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
                let bundleId = Bundle.main.bundleIdentifier ?? "co.cronx.sparkapp"
            #if DEBUG
                let appEnvironment = "sandbox"
            #else
                let appEnvironment = "production"
            #endif

                if let registered = try? await apiClient.request(DevicesEndpoint.register(
                    name: name, platform: "ios",
                    apnsToken: apnsToken, appEnvironment: appEnvironment,
                    appVersion: appVersion, bundleId: bundleId, osVersion: osVersion
                )) {
                    UserDefaults.sparkAppGroup.set(registered.id, forKey: "spark.apnsDeviceId")
                }
            }
            deviceRegistrationTokenInFlight = apnsToken
            deviceRegistrationTask = task
            await task.value
            deviceRegistrationTask = nil
            deviceRegistrationTokenInFlight = nil
            return
        }
    }

    func sendTestPush() async throws {
        _ = try await apiClient.request(DevicesEndpoint.sendTestPush())
    }

    func signIn(anchor: ASPresentationAnchorHandle) async {
        do {
            try await authService.signIn(presentationAnchor: anchor.value)
            session = .loggedIn
            await fetchAndCacheUserId()
            await registerDevice()
            lastError = nil
        } catch AuthenticationError.cancelled {
            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            if case let APIError.httpStatus(status, _, url) = error {
                SentrySDK.capture(message: "Auth sign-in HTTP error \(status) at \(url.absoluteString)")
            }
            SentrySDK.capture(error: error)
        }
    }

    /// App Group defaults that belong to the signed-in user.
    ///
    /// `spark.env.name` is deliberately absent: it is a build/environment
    /// override, not user data, and clearing it would silently move the next
    /// sign-in back to production.
    private static let userScopedDefaultsKeys = [
        "spark.userId",
        "spark.profile.name",
        "spark.apnsToken",
        "spark.apnsDeviceId",
        "onboarding.completed",
        "onboarding.lastStep",
        "health.upload.enabled",
        "spark.background.mode",
        "spark.checkin.legacyCleared.v1",
    ]

    /// Set while a server-side revocation is owed.
    ///
    /// Holds only an opaque device id — never a credential — so it is safe to
    /// persist across launches until the revocation succeeds.
    static let pendingDeviceRevocationKey = "spark.pendingDeviceRevocation"

    /// Ends the session and removes every trace of the departing user.
    ///
    /// One idempotent coordinator rather than a sequence spread across views:
    /// sign-out previously revoked the device registration and cleared the
    /// token pair and ETags, but left SwiftData, the App Group defaults, the
    /// Core Spotlight index, delivered notifications and the APNs registration
    /// intact — all of which the next account could see. `spark.profile.name`
    /// was even re-read at init, so the previous user's display name came back.
    ///
    /// Revocation and privacy-sensitive local erasure must complete before the
    /// credentials are cleared and another account can enter the shared store.
    func signOut() async {
        guard await revokeRemoteDevice() else {
            lastError = "Couldn't revoke this device. Spark will retry when the connection returns."
            return
        }

        do {
            try await purgeLocalState()
            UserDefaults.sparkAppGroup.removeObject(forKey: Self.pendingDeviceRevocationKey)
            session = .loggedOut
            lastError = nil
        } catch {
            SparkObservability.captureHandled(error)
            SentrySDK.capture(error: error)
            lastError = "Couldn't finish signing out. Please try again before changing accounts."
        }
    }

    /// Revokes a pending device while this account's authorization is intact.
    private func revokeRemoteDevice() async -> Bool {
        let defaults = UserDefaults.sparkAppGroup
        let deviceId = defaults.string(forKey: Self.pendingDeviceRevocationKey)
            ?? defaults.string(forKey: "spark.apnsDeviceId")

        if let deviceId {
            // Persist before the request so termination or an offline failure
            // cannot lose the id needed by the foreground retry.
            defaults.set(deviceId, forKey: Self.pendingDeviceRevocationKey)

            guard await tokenStore.accessToken() != nil else { return false }
            do {
                _ = try await apiClient.request(DevicesEndpoint.revoke(id: deviceId))
            } catch APIError.httpStatus(404, _, _) {
                // A missing device is terminal: the desired server state has
                // already been reached.
            } catch {
                SparkObservability.captureHandled(error)
                return false
            }
        }

        return true
    }

    /// Removes all locally held user state. Idempotent.
    private func purgeLocalState() async throws {
        // Both durable stores are erased before credentials. If either throws,
        // the current account stays active and can safely retry; a second
        // account is never admitted to partially purged shared state.
        try purgeDataStore(container)
        try await purgeSpotlight()

        // Invalidate the remote session only once durable local erasure has
        // succeeded. Until this point a failed purge must keep the departing
        // account usable so sign-out can be retried safely.
        if await tokenStore.accessToken() != nil {
            _ = try? await apiClient.request(SessionEndpoint.logout())
        }

        for key in Self.userScopedDefaultsKeys {
            UserDefaults.sparkAppGroup.removeObject(forKey: key)
        }

        // Recent searches live in standard defaults rather than the App Group.
        UserDefaults.standard.removeObject(forKey: "spark.search.recents")

        await authService.signOut()
        await etagCache.clearAll()
        profile = nil
        pendingRoute = nil

        await endAllLiveActivities()
        await reverbDisconnect()

        clearDeliveredNotifications()
        unregisterForRemoteNotifications()

        WidgetCenter.shared.reloadAllTimelines()
    }

    private func endAllLiveActivities() async {
        await LiveActivityManager.shared.endAll()
    }

    /// Clears notifications already sitting in Notification Center.
    ///
    /// Delivered notifications survive sign-out and can carry the departing
    /// user's content in their title and body.
    private func clearDeliveredNotifications() {
        #if canImport(UIKit)
            let center = UNUserNotificationCenter.current()
            center.removeAllDeliveredNotifications()
            center.removeAllPendingNotificationRequests()
            center.setBadgeCount(0)
        #endif
    }

    /// Stops APNs delivery to this install.
    ///
    /// Without this the device keeps its APNs registration after sign-out, so
    /// pushes intended for the previous user can still arrive.
    private func unregisterForRemoteNotifications() {
        #if canImport(UIKit)
            UIApplication.shared.unregisterForRemoteNotifications()
        #endif
    }
}

#if canImport(UIKit)
import AuthenticationServices
import UIKit

/// Thin wrapper around `ASPresentationAnchor` so the model stays UIKit-agnostic
/// for testability while still giving `AuthenticationService` the window it
/// needs.
struct ASPresentationAnchorHandle {
    let value: ASPresentationAnchor

    @MainActor
    static func current() -> ASPresentationAnchorHandle? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard
            let anchor = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
                ?? scenes.first.map(UIWindow.init(windowScene:))
        else { return nil }
        return .init(value: anchor)
    }
}
#endif
