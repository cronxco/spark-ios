import Foundation
import Observation
import Sentry
import SparkHealth
import SparkKit
import SparkSync
import SwiftData
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
    case integration(service: String)
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

    init(container: ModelContainer) {
        self.container = container
        let tokenStore = KeychainTokenStore()
        let etagCache = ETagCache()
        let client = APIClient(tokenStore: tokenStore, etagCache: etagCache)
        self.tokenStore = tokenStore
        self.etagCache = etagCache
        self.apiClient = client
        self.authService = AuthenticationService(tokenStore: tokenStore, apiClient: client)
        self.reverb = ReverbClient(tokenStore: tokenStore)
        self.onboardingComplete = UserDefaults(suiteName: "group.co.cronx.spark")?.bool(forKey: "onboarding.completed") == true
    }

    func bootstrap() async {
        if let token = await tokenStore.accessToken() {
            onboardingComplete = true
            session = .loggedIn
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
                _ = await DeltaSyncer.sync(using: client, container: cont)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// Connect Reverb when the app is in the foreground.
    /// The user ID is cached in UserDefaults after bootstrap via GET /me.
    func reverbConnect() async {
        guard session == .loggedIn else { return }
        let userId = UserDefaults.sparkAppGroup.string(forKey: "spark.userId") ?? ""
        guard !userId.isEmpty else { return }
        await reverb.connect(userId: userId)
    }

    /// Disconnect Reverb when the app moves to the background.
    func reverbDisconnect() async {
        await reverb.disconnect()
    }

    /// Read a route written by an AppIntent (from the extension process) and
    /// navigate to it. Consumed once to prevent stale navigation on re-launch.
    private func consumePendingIntentRoute() {
        let defaults = UserDefaults(suiteName: "group.co.cronx.spark")
        guard let raw = defaults?.string(forKey: "spark.pendingRoute") else { return }
        defaults?.removeObject(forKey: "spark.pendingRoute")
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard let kind = parts.first else { return }
        switch kind {
        case "today":   pendingRoute = .today(date: nil)
        case "event":   if let id = parts.last { pendingRoute = .event(id: id) }
        case "metric":  if let id = parts.last { pendingRoute = .metric(identifier: id) }
        case "place":   if let id = parts.last { pendingRoute = .place(id: id) }
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
        guard let profile = try? await apiClient.request(MeEndpoint.get()) else { return }
        UserDefaults.sparkAppGroup.set(profile.id, forKey: "spark.userId")
    }

    private func configureHealthUploader(accessToken: String) {
        HealthSampleUploader.shared.configure(
            environment: APIEnvironment.current(),
            accessToken: accessToken
        )
    }

    private func registerDevice() async {
        #if canImport(UIKit)
        let name = UIDevice.current.name
        #else
        let name = "Unknown"
        #endif
        _ = try? await apiClient.request(DevicesEndpoint.register(name: name, platform: "ios"))
    }

    func signIn(anchor: ASPresentationAnchorHandle) async {
        do {
            try await authService.signIn(presentationAnchor: anchor.value)
            session = .loggedIn
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

    func signOut() async {
        await authService.signOut()
        await etagCache.clearAll()
        session = .loggedOut
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
