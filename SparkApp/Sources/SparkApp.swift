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
    static let dsn = "https://ef59ff58e715b792543b367d5dcc8748@sentry.cronx.co/10"

    static func start() {
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = APIEnvironment.current().name
            options.releaseName = releaseName()
            #if DEBUG
            options.debug = true
            options.tracesSampleRate = 1.0
            #else
            options.tracesSampleRate = 0.2
            #endif
            options.attachScreenshot = true
            options.attachViewHierarchy = false
            options.enableTimeToFullDisplayTracing = true
        }
    }

    private static func releaseName() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "co.cronx.spark@\(short)+\(build)"
    }
}
