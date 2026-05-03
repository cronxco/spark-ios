import SwiftUI
import WidgetKit

struct SleepScoreWidget: Widget {
    let kind = "co.cronx.spark.widgets.sleep"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SparkTimelineProvider()) { entry in
            SleepScoreWidgetView(entry: entry)
        }
        .configurationDisplayName("Sleep Score")
        .description("Today's sleep score and duration.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct SleepScoreWidgetView: View {
    let entry: SparkWidgetEntry

    var body: some View {
        let snap = entry.snapshot
        ZStack {
            containerBG
            VStack(alignment: .leading, spacing: 4) {
                Label("Sleep", systemImage: "moon.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(alignment: .center, spacing: 10) {
                    RingView.sleep(
                        progress: sleepProgress(snap),
                        size: 52
                    )
                    .overlay {
                        if let score = snap.sleepScore {
                            Text("\(score)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        if let score = snap.sleepScore {
                            Text("\(score)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                        } else {
                            Text("—")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        if let dur = snap.sleepDurationDisplay {
                            Text(dur)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }
            .padding(14)
        }
        .widgetURL(URL(string: "https://spark.cronx.co/metrics/sleep.score"))
    }

    private var containerBG: some View {
        ContainerRelativeShape()
            .fill(.indigo.opacity(0.12))
            .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private func sleepProgress(_ snap: WidgetDataSnapshot) -> Double {
        guard let score = snap.sleepScore else { return 0 }
        return Double(score) / 100.0
    }
}
