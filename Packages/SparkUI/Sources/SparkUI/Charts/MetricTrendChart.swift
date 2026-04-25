import Charts
import SparkKit
import SwiftUI

/// Swift Charts wrapper for metric trends. Renders:
///   • baseline band (RectangleMark) under everything
///   • area fill + line trend (AreaMark + LineMark)
///   • anomaly pins (PointMark with warning tint)
///   • a final marker on the latest data point
///
/// VoiceOver gets an `AccessibilityChartDescriptor` so users can navigate
/// the series with the rotor.
public struct MetricTrendChart: View {
    public let series: [MetricDetail.Point]
    public let baseline: MetricDetail.Baseline?
    public let anomalies: [MetricDetail.AnomalyPoint]
    public let valueForAnomaly: (MetricDetail.AnomalyPoint) -> Double?
    public let tint: Color
    public let height: CGFloat

    public init(
        series: [MetricDetail.Point],
        baseline: MetricDetail.Baseline?,
        anomalies: [MetricDetail.AnomalyPoint],
        valueForAnomaly: @escaping (MetricDetail.AnomalyPoint) -> Double?,
        tint: Color = .sparkAccent,
        height: CGFloat = 180
    ) {
        self.series = series
        self.baseline = baseline
        self.anomalies = anomalies
        self.valueForAnomaly = valueForAnomaly
        self.tint = tint
        self.height = height
    }

    public var body: some View {
        Chart {
            if let baseline {
                RectangleMark(
                    yStart: .value("Baseline low", baseline.low),
                    yEnd: .value("Baseline high", baseline.high)
                )
                .foregroundStyle(.primary.opacity(0.05))

                RuleMark(y: .value("Baseline low", baseline.low))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                RuleMark(y: .value("Baseline high", baseline.high))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            }

            ForEach(series) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint.opacity(0.40), tint.opacity(0.00)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }

            ForEach(anomalies) { anomaly in
                if let value = valueForAnomaly(anomaly) {
                    PointMark(
                        x: .value("Date", anomaly.date),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(Color.sparkWarning)
                    .symbolSize(80)
                    .annotation(position: .top, spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.sparkWarning)
                            .accessibilityHidden(true)
                    }
                }
            }

            if let last = series.last {
                PointMark(
                    x: .value("Today", last.date),
                    y: .value("Today", last.value)
                )
                .foregroundStyle(tint)
                .symbolSize(100)
                .symbol(.circle)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis(.hidden)
        .frame(height: height)
        .accessibilityChartDescriptor(self)
    }
}

extension MetricTrendChart: AXChartDescriptorRepresentable {
    nonisolated public func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Date",
            range: (series.first?.date.timeIntervalSince1970 ?? 0)
                ... (series.last?.date.timeIntervalSince1970 ?? 1),
            gridlinePositions: []
        ) { value in
            Date(timeIntervalSince1970: value).formatted(date: .abbreviated, time: .omitted)
        }

        let values = series.map(\.value)
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Value",
            range: (values.min() ?? 0) ... (values.max() ?? 1),
            gridlinePositions: []
        ) { "\($0)" }

        let dataSeries = AXDataSeriesDescriptor(
            name: "Trend",
            isContinuous: true,
            dataPoints: series.map { point in
                AXDataPoint(
                    x: point.date.timeIntervalSince1970,
                    y: point.value
                )
            }
        )

        return AXChartDescriptor(
            title: "Metric trend",
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [dataSeries]
        )
    }
}
