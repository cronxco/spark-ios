import Sentry
import SparkKit
import SparkUI
import SwiftData
import SwiftUI

@main
struct SparkApp: App {
    @State private var model = AppModel.shared

    init() {
        SparkObservability.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(model.container)
                .tint(.sparkAccent)
                .sparkDynamicTypeClamp()
        }
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

    private static func releaseName() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "co.cronx.spark@\(short)+\(build)"
    }
}
