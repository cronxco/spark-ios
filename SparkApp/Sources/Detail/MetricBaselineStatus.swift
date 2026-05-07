import Foundation
import SparkKit

struct MetricBaselineStatus: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case normal
        case high
        case low
    }

    let metricIdentifier: String
    let state: State
    let title: String
    let trailing: String

    static func make(
        event: Event,
        metric: MetricDetail,
        metricIdentifier: String? = nil,
        calendar: Calendar = .current
    ) -> MetricBaselineStatus? {
        guard let baseline = metric.baseline,
              baseline.low <= baseline.high,
              baseline.low.isFinite,
              baseline.high.isFinite,
              let value = value(for: event, in: metric, calendar: calendar)
        else {
            return nil
        }

        let normalLow = max(0, baseline.low)

        if value >= normalLow && value <= baseline.high {
            return MetricBaselineStatus(
                metricIdentifier: metricIdentifier ?? metric.id,
                state: .normal,
                title: "Normal",
                trailing: formatRange(low: normalLow, high: baseline.high, unit: event.unit ?? metric.unit)
            )
        }

        if value > baseline.high {
            guard baseline.high != 0 else { return nil }
            return MetricBaselineStatus(
                metricIdentifier: metricIdentifier ?? metric.id,
                state: .high,
                title: "Outside Normal Range",
                trailing: formatPercent((value - baseline.high) / abs(baseline.high))
            )
        }

        guard normalLow != 0 else { return nil }
        return MetricBaselineStatus(
            metricIdentifier: metricIdentifier ?? metric.id,
            state: .low,
            title: "Outside Normal Range",
            trailing: formatPercent(-((normalLow - value) / abs(normalLow)))
        )
    }

    private static func value(for event: Event, in metric: MetricDetail, calendar: Calendar) -> Double? {
        if let eventDate = event.time,
           let point = metric.series.first(where: { calendar.isDate($0.date, inSameDayAs: eventDate) }) {
            return point.value
        }

        guard let rawValue = event.value?.sparkPlainTextFromHTMLFragment else {
            return nil
        }
        return parseNumber(rawValue)
    }

    private static func parseNumber(_ rawValue: String) -> Double? {
        let allowed = CharacterSet(charactersIn: "-0123456789.")
        let filtered = rawValue
            .replacingOccurrences(of: ",", with: "")
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map(String.init)
            .joined()
        return Double(filtered)
    }

    private static func formatRange(low: Double, high: Double, unit: String?) -> String {
        "\(formatValue(low, unit: unit))-\(formatValue(high, unit: unit))"
    }

    private static func formatValue(_ value: Double, unit: String?) -> String {
        if let unit, ["GBP", "USD", "EUR", "JPY"].contains(unit.uppercased()) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = unit.uppercased()
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = value.rounded() == value ? 0 : 2
            return formatter.string(from: NSNumber(value: value)) ?? compactNumber(value)
        }

        let number = compactNumber(value)
        guard let unit, !unit.isEmpty else {
            return number
        }

        if unit == "%" || unit.lowercased() == "percent" {
            return "\(number)%"
        }
        return "\(number) \(unit)"
    }

    private static func compactNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func formatPercent(_ ratio: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.positivePrefix = "+"
        return formatter.string(from: NSNumber(value: ratio)) ?? "\(Int((ratio * 100).rounded()))%"
    }
}
