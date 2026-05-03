import AppIntents
import SparkIntelligence
import SparkKit
import SwiftUI
import WidgetKit

struct TodayDashboardWidget: Widget {
    let kind = "co.cronx.spark.widgets.today-dashboard"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SparkTimelineProvider()) { entry in
            TodayDashboardWidgetView(entry: entry)
        }
        .configurationDisplayName("Today Dashboard")
        .description("Full today summary with anomalies.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

struct TodayDashboardWidgetView: View {
    let entry: SparkWidgetEntry

    var body: some View {
        let snap = entry.snapshot
        VStack(alignment: .leading, spacing: 12) {
            headerRow(snap)
            Divider().opacity(0.3)
            metricsRow(snap)
            if !snap.anomalies.isEmpty {
                Divider().opacity(0.3)
                anomalyList(snap.anomalies)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .containerBackground(for: .widget) { Color(.systemBackground) }
        .widgetURL(URL(string: "https://spark.cronx.co/today"))
    }

    // MARK: - Sub-views

    private func headerRow(_ snap: WidgetDataSnapshot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.headline.weight(.bold))
                Text(snap.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                RingView.move(progress: snap.moveProgress, size: 36)
                RingView.exercise(progress: snap.exerciseProgress, size: 26)
                RingView.stand(progress: snap.standProgress, size: 18)
            }
        }
    }

    private func metricsRow(_ snap: WidgetDataSnapshot) -> some View {
        HStack(spacing: 16) {
            metricTile(
                icon: "moon.fill",
                color: .indigo,
                value: snap.sleepScore.map { "\($0)" } ?? "—",
                sub: snap.sleepDurationDisplay ?? "No data",
                url: "https://spark.cronx.co/metrics/sleep.score"
            )
            Divider().frame(maxHeight: 48).opacity(0.3)
            metricTile(
                icon: "figure.walk",
                color: .green,
                value: snap.stepsDisplay,
                sub: "steps",
                url: "https://spark.cronx.co/metrics/health.steps"
            )
            Divider().frame(maxHeight: 48).opacity(0.3)
            metricTile(
                icon: "creditcard.fill",
                color: .orange,
                value: snap.spentTodayDisplay ?? "—",
                sub: "spent",
                url: "https://spark.cronx.co/metrics/money.spend"
            )
        }
    }

    private func metricTile(icon: String, color: Color, value: String, sub: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(value, systemImage: icon)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(sub)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func anomalyList(_ anomalies: [Anomaly]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Anomalies")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(anomalies.prefix(3)) { anomaly in
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(anomaly.displayName ?? anomaly.metric ?? anomaly.id)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    // Interactive acknowledge button (iOS 17+)
                    Button(
                        intent: AcknowledgeAnomalyIntent(anomalyID: anomaly.id)
                    ) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
