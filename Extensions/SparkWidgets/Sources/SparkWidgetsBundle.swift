import SwiftUI
import WidgetKit

@main
struct SparkWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Home Screen — small
        SleepScoreWidget()
        StepsRingWidget()
        SpendTodayWidget()
        NextEventWidget()
        // Home Screen — medium / large
        TodayGlanceWidget()
        TodayDashboardWidget()
        // Lock Screen
        SleepCircularWidget()
        StepsCircularWidget()
        TopMetricRectangularWidget()
        NextEventInlineWidget()
        // StandBy
        StandByWidget()
    }
}
