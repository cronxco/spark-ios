import Charts
import SwiftUI

/// Compact bar-chart hypnogram rendering sleep depth (0…1) over the night.
/// Used inline in the Sleep card. Decorative — the value is conveyed by the
/// surrounding metric copy, so this component is hidden from VoiceOver.
public struct SleepHypnogram: View {
    public struct Stage: Identifiable, Sendable {
        public let id: Int
        public let depth: Double

        public init(id: Int, depth: Double) {
            self.id = id
            self.depth = depth
        }
    }

    public let stages: [Stage]
    public let tint: Color
    public let height: CGFloat

    public init(
        stages: [Stage],
        tint: Color = .ocean300,
        height: CGFloat = 36
    ) {
        self.stages = stages
        self.tint = tint
        self.height = height
    }

    public var body: some View {
        Chart(stages) { stage in
            BarMark(
                x: .value("Stage", stage.id),
                y: .value("Depth", stage.depth)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [tint.opacity(0.55), tint],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .cornerRadius(1)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0 ... 1)
        .chartPlotStyle { $0.padding(.vertical, 0) }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

#Preview("Hypnogram") {
    SleepHypnogram(stages: (0 ..< 28).map { i in
        let v = [0.4, 0.6, 0.85, 0.9, 0.95, 1.0, 0.85, 0.7, 0.45, 0.3,
                 0.5, 0.7, 0.9, 0.7, 0.4, 0.5, 0.6, 0.45, 0.3, 0.5,
                 0.65, 0.85, 0.9, 0.7, 0.5, 0.4, 0.55, 0.3]
        return SleepHypnogram.Stage(id: i, depth: v[i % v.count])
    })
    .padding()
    .background(Color.sparkSurface)
}
