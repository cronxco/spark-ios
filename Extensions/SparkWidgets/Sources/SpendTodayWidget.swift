import SwiftUI
import WidgetKit

struct SpendTodayWidget: Widget {
    let kind = "co.cronx.spark.widgets.spend"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SparkTimelineProvider()) { entry in
            SpendTodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Spend")
        .description("How much you've spent today.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct SpendTodayWidgetView: View {
    let entry: SparkWidgetEntry

    var body: some View {
        let snap = entry.snapshot
        ZStack {
            containerBG
            VStack(alignment: .leading, spacing: 4) {
                Label("Spend", systemImage: "creditcard.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    if let display = snap.spentTodayDisplay {
                        Text(display)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("spent today")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No spend")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("today")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .padding(14)
        }
        .widgetURL(URL(string: "https://spark.cronx.co/metrics/money.spend"))
    }

    private var containerBG: some View {
        ContainerRelativeShape()
            .fill(.orange.opacity(0.10))
            .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}
