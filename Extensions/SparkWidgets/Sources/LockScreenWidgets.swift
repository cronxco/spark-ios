import SwiftUI
import WidgetKit

// MARK: - Circular (sleep ring + steps ring)

struct SleepCircularWidget: Widget {
    let kind = "co.cronx.spark.widgets.sleep-circular"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SparkTimelineProvider()) { entry in
            SleepCircularView(entry: entry)
        }
        .configurationDisplayName("Sleep Ring")
        .description("Sleep score progress ring on the Lock Screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct SleepCircularView: View {
    let entry: SparkWidgetEntry

    var body: some View {
        let progress = Double(entry.snapshot.sleepScore ?? 0) / 100.0
        ZStack {
            RingView(
                progress: progress,
                lineWidth: 5,
                gradient: AngularGradient(
                    colors: [.indigo, .purple],
                    center: .center,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(270)
                )
            )
            if let score = entry.snapshot.sleepScore {
                Text("\(score)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            } else {
                Image(systemName: "moon.fill")
                    .font(.caption)
            }
        }
        .widgetURL(URL(string: "https://spark.cronx.co/metrics/sleep.score"))
    }
}

struct StepsCircularWidget: Widget {
    let kind = "co.cronx.spark.widgets.steps-circular"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SparkTimelineProvider()) { entry in
            StepsCircularView(entry: entry)
        }
        .configurationDisplayName("Steps Ring")
        .description("Step count progress ring on the Lock Screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct StepsCircularView: View {
    let entry: SparkWidgetEntry

    var body: some View {
        let snap = entry.snapshot
        let progress = Double(snap.steps ?? 0) / Double(snap.stepsGoal)
        ZStack {
            RingView(
                progress: progress,
                lineWidth: 5,
                gradient: AngularGradient(
                    colors: [.green, .mint],
                    center: .center,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(270)
                )
            )
            Text(snap.stepsDisplay)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .widgetURL(URL(string: "https://spark.cronx.co/metrics/health.steps"))
    }
}

// MARK: - Rectangular (top metric)

struct TopMetricRectangularWidget: Widget {
    let kind = "co.cronx.spark.widgets.top-metric-rect"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SparkTimelineProvider()) { entry in
            TopMetricRectangularView(entry: entry)
        }
        .configurationDisplayName("Top Metric")
        .description("Your most important metric on the Lock Screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct TopMetricRectangularView: View {
    let entry: SparkWidgetEntry

    var body: some View {
        let snap = entry.snapshot
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Sleep", systemImage: "moon.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(snap.sleepScore.map { "\($0)" } ?? "—")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                if let dur = snap.sleepDurationDisplay {
                    Text(dur)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Label("Steps", systemImage: "figure.walk")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(snap.stepsDisplay)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
        }
        .widgetURL(URL(string: "https://spark.cronx.co/today"))
    }
}

// MARK: - Inline (next event)

struct NextEventInlineWidget: Widget {
    let kind = "co.cronx.spark.widgets.next-event-inline"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SparkTimelineProvider()) { entry in
            NextEventInlineView(entry: entry)
        }
        .configurationDisplayName("Next Event")
        .description("Your next calendar event as a Lock Screen inline widget.")
        .supportedFamilies([.accessoryInline])
    }
}

struct NextEventInlineView: View {
    let entry: SparkWidgetEntry

    var body: some View {
        let snap = entry.snapshot
        if let title = snap.nextEventTitle {
            let time = snap.nextEventStart.map { " · \($0)" } ?? ""
            Label("\(title)\(time)", systemImage: "calendar")
        } else {
            Label("No upcoming events", systemImage: "calendar")
        }
    }
}
