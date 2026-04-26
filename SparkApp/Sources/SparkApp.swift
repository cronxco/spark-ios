import Sentry
import SparkHealth
import SparkKit
import SparkUI
import SwiftData
import SwiftUI

@main
struct SparkApp: App {
    @UIApplicationDelegateAdaptor(SparkAppDelegate.self) var appDelegate
    @State private var model = AppModel.shared

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
        }
    }
}

/// Temporary AppDelegate adaptor. Handles background URLSession events for
/// HealthKit sample uploads. Will be consolidated in Week 4 D16.
final class SparkAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        HealthSampleUploader.shared.addCompletionHandler(completionHandler, for: identifier)
    }
}

enum SparkObservability {
    static let dsn = "https://1583f3671989ff49f2e578e5cef8ace9@sentry.cronx.co/5"

    static func start() {
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = APIEnvironment.current().name
            options.releaseName = releaseName()

            // Error monitoring
            options.enableCrashHandler = true
            options.enableWatchdogTerminationTracking = true
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            options.enableTimeToFullDisplayTracing = true

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
            options.tracesSampleRate = 0.2
            options.configureProfiling = {
                $0.sessionSampleRate = 0.1
                $0.lifecycle = .trace
            }
            #endif
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
}
