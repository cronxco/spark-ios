import ActivityKit
import SparkKit
import SwiftUI
import WidgetKit

// MARK: - Lock Screen layout

struct RingsLockScreenView: View {
    let context: ActivityViewContext<DailyActivityAttributes>

    var body: some View {
        HStack(spacing: 20) {
            // Nested rings (move → exercise → stand)
            ZStack {
                ring(progress: context.state.moveProgress, color: .red, size: 70, lineWidth: 8)
                ring(progress: context.state.exerciseProgress, color: .green, size: 52, lineWidth: 7)
                ring(progress: context.state.standProgress, color: .cyan, size: 36, lineWidth: 6)
            }

            VStack(alignment: .leading, spacing: 6) {
                metricRow(icon: "figure.walk", color: .green, label: "\(context.state.stepsDisplay) steps")
                metricRow(icon: "flame.fill", color: .red, label: moveLabel)
                metricRow(icon: "bolt.fill", color: .cyan, label: standLabel)
            }

            Spacer()
        }
        .padding(16)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.green.opacity(0.2), Color.teal.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var moveLabel: String {
        let pct = Int(context.state.moveProgress * 100)
        return "Move \(pct)%"
    }

    private var standLabel: String {
        let pct = Int(context.state.standProgress * 100)
        return "Stand \(pct)%"
    }

    private func ring(progress: Double, color: Color, size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }

    private func metricRow(icon: String, color: Color, label: String) -> some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

// MARK: - Dynamic Island compact views

struct RingsIslandCompactLeading: View {
    let state: DailyActivityAttributes.DailyContentState
    var body: some View {
        HStack(spacing: 2) {
            miniRing(progress: state.moveProgress, color: .red)
            miniRing(progress: state.exerciseProgress, color: .green)
            miniRing(progress: state.standProgress, color: .cyan)
        }
    }
    private func miniRing(progress: Double, color: Color) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.3), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 14, height: 14)
    }
}

struct RingsIslandCompactTrailing: View {
    let state: DailyActivityAttributes.DailyContentState
    var body: some View {
        Text(state.stepsDisplay)
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(.green)
    }
}
