import ActivityKit
import SparkKit
import SwiftUI
import WidgetKit

@main
struct SparkLiveActivitiesBundle: WidgetBundle {
    var body: some Widget {
        SleepLiveActivity()
        DailyActivityLiveActivity()
    }
}

// MARK: - Sleep Live Activity

struct SleepLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SleepActivityAttributes.self) { context in
            SleepLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.phaseLabel)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    } icon: {
                        SleepIslandCompactLeading(state: context.state)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SleepIslandCompactTrailing(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let dur = context.state.durationDisplay {
                        Text(dur)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
            } compactLeading: {
                SleepIslandCompactLeading(state: context.state)
            } compactTrailing: {
                SleepIslandCompactTrailing(state: context.state)
            } minimal: {
                SleepIslandCompactLeading(state: context.state)
            }
        }
    }
}

// MARK: - Daily Activity Rings Live Activity

struct DailyActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailyActivityAttributes.self) { context in
            RingsLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RingsIslandCompactLeading(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RingsIslandCompactTrailing(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        Label("Move \(Int(context.state.moveProgress * 100))%", systemImage: "flame.fill")
                            .foregroundStyle(.red)
                        Label("Exercise \(Int(context.state.exerciseProgress * 100))%", systemImage: "bolt.fill")
                            .foregroundStyle(.green)
                        Label("Stand \(Int(context.state.standProgress * 100))%", systemImage: "figure.stand")
                            .foregroundStyle(.cyan)
                    }
                    .font(.caption2)
                }
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
            } compactLeading: {
                RingsIslandCompactLeading(state: context.state)
            } compactTrailing: {
                RingsIslandCompactTrailing(state: context.state)
            } minimal: {
                // Show the most-progressed ring as the minimal indicator
                let p = max(context.state.moveProgress,
                            context.state.exerciseProgress,
                            context.state.standProgress)
                ZStack {
                    Circle().stroke(Color.green.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: p)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 14, height: 14)
            }
        }
    }
}
