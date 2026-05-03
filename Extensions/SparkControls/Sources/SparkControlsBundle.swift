import AppIntents
import SwiftUI
import WidgetKit

@main
struct SparkControlsBundle: WidgetBundle {
    var body: some Widget {
        QuickCheckInControl()
        OpenTodayControl()
        FocusDomainControl()
    }
}

// MARK: - Quick Check-In

struct QuickCheckInControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "co.cronx.spark.controls.checkin") {
            ControlWidgetButton(action: QuickCheckInAction()) {
                Label("Check In", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Quick Check-In")
        .description("Log a mood check-in without opening Spark.")
    }
}

struct QuickCheckInAction: AppIntent {
    static let title: LocalizedStringResource = "Quick Check-In"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        // Phase 3 Week 3: drive LogCheckInIntent from SparkIntelligence
        .result()
    }
}

// MARK: - Open Today

struct OpenTodayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "co.cronx.spark.controls.open-today") {
            ControlWidgetButton(action: OpenTodayAction()) {
                Label("Open Spark", systemImage: "sparkles")
            }
        }
        .displayName("Open Spark")
        .description("Open the Spark Today view from Control Center.")
    }
}

struct OpenTodayAction: AppIntent {
    static let title: LocalizedStringResource = "Open Today"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult { .result() }
}

// MARK: - Focus Domain Toggle

struct FocusDomainControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "co.cronx.spark.controls.focus-domain") {
            ControlWidgetButton(action: FocusDomainAction()) {
                Label("Focus", systemImage: "scope")
            }
        }
        .displayName("Spark Focus")
        .description("Toggle the active focus domain filter in Spark.")
    }
}

struct FocusDomainAction: AppIntent {
    static let title: LocalizedStringResource = "Toggle Focus Domain"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult { .result() }
}
