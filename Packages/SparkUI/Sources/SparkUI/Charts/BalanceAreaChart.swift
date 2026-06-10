import Charts
import SwiftUI

public struct BalanceAreaChart: View {
    public struct Point: Identifiable {
        public let id: UUID
        public let date: Date
        public let value: Double

        public init(id: UUID = UUID(), date: Date, value: Double) {
            self.id = id
            self.date = date
            self.value = value
        }
    }

    let data: [Point]
    let tint: Color
    let showXAxis: Bool
    let showMidline: Bool
    let showEndpoint: Bool

    public init(
        data: [Point],
        tint: Color,
        showXAxis: Bool = false,
        showMidline: Bool = false,
        showEndpoint: Bool = false
    ) {
        self.data = data
        self.tint = tint
        self.showXAxis = showXAxis
        self.showMidline = showMidline
        self.showEndpoint = showEndpoint
    }

    public var body: some View {
        Chart {
            if showMidline, let midValue {
                RuleMark(y: .value("Midline", midValue))
                    .foregroundStyle(Color.secondary.opacity(0.22))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 6]))
            }

            ForEach(data) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Balance", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint.opacity(0.35), tint.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Balance", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))

                if showEndpoint, point.id == data.last?.id {
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", point.value)
                    )
                    .foregroundStyle(tint)
                    .symbolSize(48)
                }
            }
        }
        .chartXAxis(showXAxis ? .automatic : .hidden)
        .chartYAxis(.hidden)
    }

    private var midValue: Double? {
        guard let min = data.map(\.value).min(), let max = data.map(\.value).max() else {
            return nil
        }
        return min + ((max - min) / 2)
    }
}
