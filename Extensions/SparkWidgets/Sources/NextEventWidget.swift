import SwiftUI
import WidgetKit

struct NextEventWidget: Widget {
    let kind = "co.cronx.spark.widgets.nextevent"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SparkTimelineProvider()) { entry in
            NextEventWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Event")
        .description("Your next calendar event.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct NextEventWidgetView: View {
    let entry: SparkWidgetEntry

    var body: some View {
        let snap = entry.snapshot
        ZStack {
            containerBG
            VStack(alignment: .leading, spacing: 4) {
                Label("Up next", systemImage: "calendar")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if let title = snap.nextEventTitle {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)

                        if let start = snap.nextEventStart {
                            Text(start)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if let location = snap.nextEventLocation {
                            Label(location, systemImage: "location.fill")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text("No upcoming events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(14)
        }
        .widgetURL(URL(string: "https://spark.cronx.co/today"))
    }

    private var containerBG: some View {
        ContainerRelativeShape()
            .fill(.blue.opacity(0.08))
            .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}
