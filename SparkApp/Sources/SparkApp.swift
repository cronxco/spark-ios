import CoreSpotlight
import Sentry
import SparkHealth
import SparkIntelligence
import SparkKit
import SparkSync
import SparkUI
import SwiftData
import SwiftUI
import UserNotifications

@main
struct SparkApp: App {
    @UIApplicationDelegateAdaptor(SparkAppDelegate.self) var appDelegate
    @State private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        SparkFonts.registerBundledFonts()
        SparkObservability.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(model.container)
                .tint(.sparkAccent)
                .sparkDynamicTypeClamp()
                .task(id: model.session) {
                    if model.session == .loggedIn {
                        HealthKitObserver.shared.startObserving()
                    }
                }
                .onContinueUserActivity(CSSearchableItemActionType, perform: handle(spotlightActivity:))
        }
        .onChange(of: scenePhase) { _, phase in
            Task { @MainActor in
                switch phase {
                case .active:
                    await model.reverbConnect()
                case .background, .inactive:
                    await model.reverbDisconnect()
                @unknown default:
                    break
                }
            }
        }
    }

    /// Spotlight tap handler. Identifiers have the form:
    /// `co.cronx.spark.{type}.{id}` — parse the type prefix and route.
    @MainActor
    private func handle(spotlightActivity activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
        let prefix = "co.cronx.spark."
        guard identifier.hasPrefix(prefix) else { return }
        let rest = identifier.dropFirst(prefix.count)
        guard let dotRange = rest.firstIndex(of: ".") else { return }
        let kind = String(rest[..<dotRange])
        let id = String(rest[rest.index(after: dotRange)...])
        guard !id.isEmpty else { return }
        switch kind {
        case "event":       model.pendingRoute = .event(id: id)
        case "block":       model.pendingRoute = .block(id: id)
        case "place":       model.pendingRoute = .place(id: id)
        case "integration": model.pendingRoute = .integration(service: id)
        default: break
        }
    }
}

final class SparkAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()
        registerBackgroundTasks()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            SilentPushHandler.handle(
                userInfo: userInfo,
                apiClient: AppModel.shared.apiClient,
                container: AppModel.shared.container,
                completion: completionHandler
            )
        }
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        HealthSampleUploader.shared.addCompletionHandler(completionHandler, for: identifier)
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let urlString = userInfo["spark.url"] as? String,
           let url = URL(string: urlString) {
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }
        completionHandler()
    }

    // MARK: - Background tasks

    private func registerBackgroundTasks() {
        // BGTasks run in a separate process context — create fresh API client
        // and container rather than accessing AppModel (which is @MainActor).
        BGTaskCoordinator.register(
            apiClient: { @Sendable in
                APIClient(tokenStore: KeychainTokenStore(), etagCache: ETagCache())
            },
            container: { @Sendable in try SparkDataStore.makeContainer() },
            onPrefetch: { @Sendable in
                guard let container = try? SparkDataStore.makeContainer() else { return }
                await SpotlightIndexer.indexBatch(container: container)
                await SpotlightIndexer.purgeStaleItems(container: container)
            }
        )
        BGTaskCoordinator.scheduleAppRefresh()
        BGTaskCoordinator.scheduleProcessingTask()
    }

    // MARK: - Notification categories

    private func registerNotificationCategories() {
        let acknowledge = UNNotificationAction(
            identifier: "ACKNOWLEDGE",
            title: "Acknowledge",
            options: .destructive
        )
        let view = UNNotificationAction(
            identifier: "VIEW",
            title: "View",
            options: .foreground
        )
        let reauth = UNNotificationAction(
            identifier: "REAUTH",
            title: "Reconnect",
            options: .foreground
        )
        let snooze = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze",
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(
                identifier: "ANOMALY",
                actions: [acknowledge, view],
                intentIdentifiers: [],
                options: .customDismissAction
            ),
            UNNotificationCategory(
                identifier: "DIGEST",
                actions: [view],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: "INTEGRATION_FAILED",
                actions: [reauth],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: "NEW_BOOKMARK",
                actions: [view],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: "CALENDAR_EVENT",
                actions: [view, snooze],
                intentIdentifiers: [],
                options: []
            ),
        ])
    }
}

enum SparkObservability {
    static let dsn = "https://1583f3671989ff49f2e578e5cef8ace9@sentry.cronx.co/5"

    static func start() {
        guard !isRunningTests else { return }

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = APIEnvironment.current().name
            options.releaseName = releaseName()
            options.maxBreadcrumbs = 200

            // Error monitoring
            options.sampleRate = 1.0
            options.enableCrashHandler = true
            options.enableWatchdogTerminationTracking = true
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            options.enableTimeToFullDisplayTracing = true

            // Network capture
            let environment = APIEnvironment.current()
            options.enableNetworkBreadcrumbs = true
            options.enableCaptureFailedRequests = true
            options.failedRequestStatusCodes = [HttpStatusCodeRange(min: 400, max: 599)]
            options.failedRequestTargets = [
                environment.baseURL.host() ?? "spark.cronx.co",
                environment.reverbHTTPBaseURL.host() ?? "ws.spark.cronx.co",
            ]
            options.tracePropagationTargets = options.failedRequestTargets

            // Logging (captures OSLog output)
            options.enableLogs = true

            #if DEBUG
            options.debug = true
            options.tracesSampleRate = 1.0
            options.configureProfiling = {
                $0.sessionSampleRate = 1.0
                $0.lifecycle = .trace
            }
            #else
            options.tracesSampleRate = 1.0
            options.configureProfiling = {
                $0.sessionSampleRate = 1.0
                $0.lifecycle = .trace
            }
            #endif
        }

        Task {
            await APITelemetry.shared.setSink(SentryAPITelemetrySink())
        }
    }

    static func captureHandled(_ error: Error) {
        SentrySDK.capture(error: error) { scope in
            scope.setTag(value: "handled", key: "error_type")
        }
    }

    private static func releaseName() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "co.cronx.spark@\(short)+\(build)"
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
