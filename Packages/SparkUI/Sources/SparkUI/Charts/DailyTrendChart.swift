import Charts
import SwiftUI

/// The Trend pattern (`docs/design-language.md` section 8): one value per
/// day, with the usual range as a band.
///
/// - `.bars` is for daily totals (steps, active energy, sleep duration,
///   spend): one bar per day from zero, earlier days at 50% fill and the
///   latest at full fill with its label. The band is drawn over the bars.
/// - `.line` is for scores and continuous readings (readiness, HRV): a line
///   with a dot and label on the latest point, the band behind it.
///
/// A day with no value is a gap, never a zero (section 1, principle 7). No
/// gridlines beyond the zero baseline under the bars.
public struct DailyTrendChart: View {
    public enum Style: Sendable {
        case bars
        case line
    }

    public struct Point: Identifiable, Hashable, Sendable {
        public let date: Date
        public let value: Double?

        public var id: Date { date }

        public init(date: Date, value: Double?) {
            self.date = date
            self.value = value
        }
    }

    let points: [Point]
    let style: Style
    let tint: Color
    let usualRange: ClosedRange<Double>?
    let latestLabel: String?
    let height: CGFloat

    /// - Parameters:
    ///   - points: one per day, oldest first.
    ///   - usualRange: the band, such as the mean plus or minus one standard
    ///     deviation; `nil` draws none.
    ///   - latestLabel: the latest value as text, drawn beside its mark.
    public init(
        points: [Point],
        style: Style,
        tint: Color,
        usualRange: ClosedRange<Double>? = nil,
        latestLabel: String? = nil,
        height: CGFloat = 112
    ) {
        self.points = points
        self.style = style
        self.tint = tint
        self.usualRange = usualRange
        self.latestLabel = latestLabel
        self.height = height
    }

    private var latest: Point? {
        points.last { $0.value != nil }
    }

    private struct Segment: Identifiable {
        let run: Int
        let date: Date
        let value: Double

        var id: Date { date }
    }

    /// Lines break across a missing day, so each run of present values is
    /// its own series.
    private var segments: [Segment] {
        var run = 0
        var result: [Segment] = []
        for point in points {
            if let value = point.value {
                result.append(Segment(run: run, date: point.date, value: value))
            } else {
                run += 1
            }
        }
        return result
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.compactMap(\.value) + [usualRange?.lowerBound, usualRange?.upperBound].compactMap { $0 }
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        switch style {
        case .bars:
            return 0...max(high * 1.08, 1)
        case .line:
            let pad = max((high - low) * 0.2, 1)
            return (low - pad)...(high + pad)
        }
    }

    public var body: some View {
        Chart {
            if style == .line, let usualRange {
                band(usualRange)
            }

            switch style {
            case .bars:
                ForEach(points) { point in
                    if let value = point.value {
                        BarMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("Value", value)
                        )
                        .foregroundStyle(tint.opacity(point.date == latest?.date ? 1 : 0.5))
                        .cornerRadius(3)
                        .annotation(position: .top, alignment: .center, spacing: 2) {
                            if point.date == latest?.date, let latestLabel {
                                latestText(latestLabel)
                            }
                        }
                    }
                }
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.primary.opacity(0.15))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                if let usualRange {
                    band(usualRange)
                }
            case .line:
                ForEach(segments) { item in
                    LineMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Value", item.value),
                        series: .value("Run", item.run)
                    )
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                }
                if let latest, let value = latest.value {
                    PointMark(
                        x: .value("Day", latest.date, unit: .day),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(tint)
                    .symbolSize(60)
                    .annotation(position: .top, alignment: .trailing, spacing: 4) {
                        if let latestLabel {
                            latestText(latestLabel)
                        }
                    }
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: labelStride)) { _ in
                AxisValueLabel(format: labelFormat, centered: true)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartLegend(.hidden)
        .frame(height: height)
    }

    private func band(_ range: ClosedRange<Double>) -> some ChartContent {
        RectangleMark(
            yStart: .value("Usual low", range.lowerBound),
            yEnd: .value("Usual high", range.upperBound)
        )
        .foregroundStyle(Color.primary.opacity(0.06))
    }

    private func latestText(_ text: String) -> some View {
        Text(text)
            .font(SparkTypography.captionStrong)
            .monospacedDigit()
            .foregroundStyle(.primary)
            .fixedSize()
    }

    /// Every day for a week; weekly for a month; monthly beyond.
    private var labelStride: Int {
        switch points.count {
        case ...8: 1
        case ...35: 7
        default: 30
        }
    }

    private var labelFormat: Date.FormatStyle {
        points.count <= 8
            ? .dateTime.weekday(.abbreviated)
            : .dateTime.day().month(.abbreviated)
    }
}

#Preview("Bars and line") {
    VStack(spacing: 24) {
        DailyTrendChart(
            points: ([12313, 8174, 8015, 11425, 7718, 11416, 12430] as [Double?]).enumerated().map { index, value in
                DailyTrendChart.Point(date: Date(timeIntervalSinceNow: Double(index - 6) * 86_400), value: value)
            },
            style: .bars,
            tint: .ember5,
            usualRange: 5460...11196,
            latestLabel: "12,430"
        )
        DailyTrendChart(
            points: ([81, 72, nil, 88, 91, 81, 83] as [Double?]).enumerated().map { index, value in
                DailyTrendChart.Point(date: Date(timeIntervalSinceNow: Double(index - 6) * 86_400), value: value)
            },
            style: .line,
            tint: .domainHealth,
            usualRange: 71.8...88.9,
            latestLabel: "83"
        )
    }
    .padding()
}
