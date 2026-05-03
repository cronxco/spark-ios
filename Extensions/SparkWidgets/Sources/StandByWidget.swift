import SwiftUI
import WidgetKit

/// A small widget optimized for StandBy mode — full-bleed dark background
/// with large readable text. iOS rotates between multiple systemSmall widgets
/// in the StandBy widget carousel automatically.
struct StandByWidget: Widget {
    let kind = "co.cronx.spark.widgets.standby"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SparkTimelineProvider()) { entry in
            StandByWidgetView(entry: entry)
        }
        .configurationDisplayName("Spark StandBy")
        .description("Spark summary in StandBy mode.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct StandByWidgetView: View {
    let entry: SparkWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let snap = entry.snapshot
        ZStack {
            // Tertiary fill adapts to StandBy's dark, night-optimized display.
            Color(.tertiarySystemBackground)
                .containerBackground(.fill.tertiary, for: .widget)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.yellow)
                    Text("Spark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(entry.date, style: .time)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    // Sleep
                    HStack(spacing: 6) {
                        Image(systemName: "moon.fill")
                            .font(.caption2)
                            .foregroundStyle(.indigo)
                        Text(snap.sleepScore.map { "\($0)/100" } ?? "No sleep data")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    // Steps
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(snap.steps.map { "\($0) steps" } ?? "No step data")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    // Spend
                    if let display = snap.spentTodayDisplay {
                        HStack(spacing: 6) {
                            Image(systemName: "creditcard.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text(display)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                    }
                }

                Spacer()
            }
            .padding(12)
        }
        .widgetURL(URL(string: "https://spark.cronx.co/today"))
    }
}
