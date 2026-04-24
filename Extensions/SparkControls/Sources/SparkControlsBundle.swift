import AppIntents
import SwiftUI
import WidgetKit

@main
struct SparkControlsBundle: WidgetBundle {
    var body: some Widget {
        PlaceholderControl()
    }
}

/// Phase 1 stub. A real control ships in Phase 3.
struct PlaceholderControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "co.cronx.spark.controls.placeholder") {
            ControlWidgetButton(action: NoopIntent()) {
                Label("Spark", systemImage: "sparkles")
            }
        }
        .displayName("Spark")
        .description("Placeholder control — real surface lands in Phase 3.")
    }
}

struct NoopIntent: AppIntent {
    static let title: LocalizedStringResource = "No-op"
    func perform() async throws -> some IntentResult { .result() }
}
