import SwiftUI
import WidgetKit

struct StepsRingWidget: Widget {
    let kind = "co.cronx.spark.widgets.steps"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SparkTimelineProvider()) { entry in
            StepsRingWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps")
        .description("Today's step count and progress ring.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct StepsRingWidgetView: View {
    let entry: SparkWidgetEntry

    var body: some View {
        let snap = entry.snapshot
        ZStack {
            containerBG
            VStack(alignment: .leading, spacing: 4) {
                Label("Steps", systemImage: "figure.walk")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(alignment: .center, spacing: 10) {
                    RingView.steps(
                        progress: Double(snap.steps ?? 0) / Double(snap.stepsGoal),
                        size: 52
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snap.stepsDisplay)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("of \(snap.stepsGoal / 1_000)k goal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(14)
        }
        .widgetURL(URL(string: "https://spark.cronx.co/metrics/health.steps"))
    }

    private var containerBG: some View {
        ContainerRelativeShape()
            .fill(.green.opacity(0.10))
            .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}
