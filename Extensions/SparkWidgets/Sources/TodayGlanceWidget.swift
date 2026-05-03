import SwiftUI
import WidgetKit

struct TodayGlanceWidget: Widget {
    let kind = "co.cronx.spark.widgets.today-glance"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SparkTimelineProvider()) { entry in
            TodayGlanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Today at a Glance")
        .description("Sleep, steps, spend, and your next event in one view.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct TodayGlanceWidgetView: View {
    let entry: SparkWidgetEntry

    var body: some View {
        let snap = entry.snapshot
        HStack(spacing: 0) {
            tileView(
                systemImage: "moon.fill",
                color: .indigo,
                value: snap.sleepScore.map { "\($0)" } ?? "—",
                label: "Sleep"
            )
            Divider().frame(maxHeight: 60).opacity(0.3)
            tileView(
                systemImage: "figure.walk",
                color: .green,
                value: snap.stepsDisplay,
                label: "Steps"
            )
            Divider().frame(maxHeight: 60).opacity(0.3)
            tileView(
                systemImage: "creditcard.fill",
                color: .orange,
                value: snap.spentTodayDisplay ?? "—",
                label: "Spend"
            )
            Divider().frame(maxHeight: 60).opacity(0.3)
            nextEventTile(snap)
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
        .widgetURL(URL(string: "https://spark.cronx.co/today"))
    }

    private func tileView(systemImage: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func nextEventTile(_ snap: WidgetDataSnapshot) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundStyle(.blue)
            if let title = snap.nextEventTitle {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if let start = snap.nextEventStart {
                    Text(start)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No events")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}
