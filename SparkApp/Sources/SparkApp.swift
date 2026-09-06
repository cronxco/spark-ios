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
            ZStack {
                SparkResolvedAppBackground()

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
            .overlay(alignment: .top) {
                SparkResolvedStatusBarBackground()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
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
    /// `co.cronx.sparkapp.{type}.{id}` — parse the type prefix and route.
    @MainActor
    private func handle(spotlightActivity activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
        let prefix = "co.cronx.sparkapp."
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
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.sparkAppGroup.set(hex, forKey: "spark.apnsToken")
        Task { await AppModel.shared.registerDevice() }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        SentrySDK.capture(error: error)
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
        let actionIdentifier = response.actionIdentifier

        // The server nests its envelope under a single `spark` dictionary
        // (ApnsChannel::applySparkEnvelope). This previously read a flat
        // `userInfo["spark.url"]`, a key the server has never emitted, so
        // tapping any notification did nothing.
        //
        // Values are lifted out here rather than passed along as a dictionary:
        // [String: Any] is not Sendable and cannot cross into the MainActor.
        let envelope = userInfo["spark"] as? [String: Any]
        let deepLink = envelope?["deep_link"] as? String
        let entityType = envelope?["entity_type"] as? String
        let entityId = envelope?["entity_id"] as? String

        Task { @MainActor in
            Self.handleNotificationAction(
                actionIdentifier: actionIdentifier,
                deepLink: deepLink,
                entityType: entityType,
                entityId: entityId
            )
        }

        completionHandler()
    }

    /// Routes a notification tap or action button.
    ///
    /// `response.actionIdentifier` was never inspected, so every action button
    /// was inert even once its category bound. Navigation goes through
    /// `AppModel.pendingRoute` rather than `UIApplication.open`, which would
    /// bounce out to universal-link handling instead of routing in-process.
    @MainActor
    static func handleNotificationAction(
        actionIdentifier: String,
        deepLink: String?,
        entityType: String?,
        entityId: String?
    ) {
        switch actionIdentifier {
        case "SNOOZE", UNNotificationDismissActionIdentifier:
            return
        default:
            break
        }

        // REAUTH sends the user to the integration regardless of the
        // notification's own deep link, since fixing auth is the point.
        if actionIdentifier == "REAUTH", entityType == "integration", let entityId {
            AppModel.shared.pendingRoute = .integration(service: entityId)
            return
        }

        if let deepLink, let route = AppModel.route(from: deepLink) {
            AppModel.shared.pendingRoute = route
            return
        }

        // No deep link: fall back to the entity reference the envelope carries.
        if let entityType, let entityId,
           let route = AppModel.route(from: "\(entityType):\(entityId)") {
            AppModel.shared.pendingRoute = route
        }
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
                let report = await SpotlightIndexer.indexBatchWithReport(container: container)
                SparkObservability.captureSpotlightIndexReport(report, source: "background")
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
            options.beforeSend = { event in
                isExpectedMetricNotFoundEvent(event) ? nil : event
            }

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
        guard !error.isAPICancellation else { return }
        SentrySDK.capture(error: error) { scope in
            scope.setTag(value: "handled", key: "error_type")
        }
    }

    static func captureSpotlightDiagnostics(_ snapshot: SpotlightDiagnosticsSnapshot, source: String) {
        let crumb = Breadcrumb(level: .info, category: "spotlight")
        crumb.type = "debug"
        crumb.message = "Spotlight diagnostics refreshed"
        crumb.data = [
            "source": source,
            "is_signed_in": snapshot.isSignedIn,
            "can_open_store": snapshot.canOpenStore,
            "total_count": snapshot.totalCount,
        ]
        SentrySDK.addBreadcrumb(crumb)
    }

    static func captureSpotlightIndexReport(_ report: SpotlightIndexReport, source: String) {
        let crumb = Breadcrumb(level: report.hasFailures ? .error : .info, category: "spotlight")
        crumb.type = "debug"
        crumb.message = "Spotlight index run"
        crumb.data = spotlightIndexContext(report, source: source)
        SentrySDK.addBreadcrumb(crumb)

        guard report.hasFailures else { return }

        SentrySDK.capture(message: "Spotlight indexing failed") { scope in
            scope.setTag(value: source, key: "spotlight.source")
            scope.setTag(value: "failed", key: "spotlight.outcome")
            scope.setContext(value: spotlightIndexContext(report, source: source), key: "spotlight_index")
        }
    }

    static func captureUserFeedback(
        comments: String,
        context: SparkFeedbackContext,
        profile: UserProfile?
    ) {
        let eventId = SentrySDK.capture(message: "User feedback for \(context.displayLabel)") { scope in
            scope.setTag(value: "true", key: "feedback")
            scope.setTag(value: context.entityType, key: "entity_type")
            scope.setTag(value: context.entityId, key: "entity_id")
            scope.setContext(value: [
                "type": context.entityType,
                "id": context.entityId,
                "title": context.title,
            ], key: "spark_entity")
        }

        let name = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = profile?.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let feedback = SentryFeedback(
            message: comments,
            name: name?.isEmpty == false ? name : nil,
            email: email?.isEmpty == false ? email : nil,
            source: .custom,
            associatedEventId: eventId
        )
        SentrySDK.capture(feedback: feedback)
    }

    private static func isExpectedMetricNotFoundEvent(_ event: Sentry.Event) -> Bool {
        guard event.exceptions?.contains(where: { $0.type == "HTTPClientError" }) == true,
              let requestURL = event.request?.url,
              let url = URL(string: requestURL),
              url.path.hasPrefix("/api/v1/mobile/metrics/")
        else {
            return false
        }

        let response = event.context?["response"]
        let statusCode = response?["status_code"] as? Int
            ?? (response?["status_code"] as? NSNumber)?.intValue
        return statusCode == 404
    }

    private static func spotlightIndexContext(_ report: SpotlightIndexReport, source: String) -> [String: Any] {
        [
            "source": source,
            "started_at": ISO8601DateFormatter().string(from: report.startedAt),
            "finished_at": report.finishedAt.map { ISO8601DateFormatter().string(from: $0) } as Any,
            "skipped_reason": report.skippedReason as Any,
            "indexed_count": report.indexedCount,
            "batches": report.batches.map {
                [
                    "name": $0.name,
                    "indexed_count": $0.indexedCount,
                    "error": $0.errorDescription as Any,
                ]
            },
        ]
    }

    private static func releaseName() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "co.cronx.sparkapp@\(short)+\(build)"
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
