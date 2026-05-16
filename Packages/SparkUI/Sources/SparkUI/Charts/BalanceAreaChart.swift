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

    public init(data: [Point], tint: Color, showXAxis: Bool = false) {
        self.data = data
        self.tint = tint
        self.showXAxis = showXAxis
    }

    public var body: some View {
        Chart(data) { point in
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
        }
        .chartXAxis(showXAxis ? .automatic : .hidden)
        .chartYAxis(.hidden)
    }
}
