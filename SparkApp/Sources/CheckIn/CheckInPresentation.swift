import SparkKit
import SparkUI
import SwiftUI

enum CheckInPresentation {
    static func scoreColor(_ score: Int?) -> Color {
        switch score {
        case 2:  Color(red: 212/255, green: 61/255,  blue: 81/255)
        case 3:  Color(red: 226/255, green: 115/255, blue: 87/255)
        case 4:  Color(red: 235/255, green: 160/255, blue: 110/255)
        case 5:  Color(red: 242/255, green: 202/255, blue: 148/255)
        case 6:  Color(red: 253/255, green: 241/255, blue: 197/255)
        case 7:  Color(red: 205/255, green: 214/255, blue: 163/255)
        case 8:  Color(red: 153/255, green: 188/255, blue: 137/255)
        case 9:  Color(red: 96/255,  green: 162/255, blue: 119/255)
        case 10: Color(red: 0/255,   green: 135/255, blue: 108/255)
        default: .secondary
        }
    }

    static func physicalEmoji(_ value: Int) -> String {
        emoji(value, from: ["💀", "😴", "🚶‍♂️", "🏃‍♂️", "💪"])
    }

    static func mentalEmoji(_ value: Int) -> String {
        emoji(value, from: ["😭", "🥹", "😕", "😊", "😄"])
    }

    static func retrospectiveTimestamp(for date: Date, period: CheckInPeriod, calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = period == .morning ? 8 : 16
        components.minute = 0
        components.second = 0
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return components.date
    }

    static func occurredAtOverride(for date: Date, period: CheckInPeriod, now: Date = .now, calendar: Calendar = .current) -> Date? {
        let targetDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        guard targetDay < today else { return nil }
        return retrospectiveTimestamp(for: date, period: period, calendar: calendar)
    }

    private static func emoji(_ value: Int, from emojis: [String]) -> String {
        let index = max(0, min(emojis.count - 1, value - 1))
        return emojis[index]
    }
}

struct CheckInPeriodSummaryRow: View {
    let title: String
    let status: PeriodStatus
    var isEnabled = true
    let onTap: () -> Void

    var body: some View {
        Group {
            switch status {
            case .pending where isEnabled:
                Button(action: onTap) { content }
                    .buttonStyle(.plain)
            default:
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var content: some View {
        HStack(alignment: .center, spacing: SparkSpacing.md) {
            Text(title)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.55))
            Spacer(minLength: SparkSpacing.md)

            switch status {
            case .pending:
                Text(isEnabled ? "tap to log" : "not logged")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            case let .completed(physical, mental, _):
                HStack(spacing: SparkSpacing.sm) {
                    Text(CheckInPresentation.physicalEmoji(physical))
                    Text(CheckInPresentation.mentalEmoji(mental))
                    Text("\(physical + mental)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(CheckInPresentation.scoreColor(physical + mental))
                        .monospacedDigit()
                }
                .font(SparkTypography.bodySmall)
            }
        }
        .padding(.vertical, SparkSpacing.xs)
        .contentShape(Rectangle())
    }

    private var accessibilityLabel: String {
        switch status {
        case .pending:
            return isEnabled ? "\(title) pending. Tap to log." : "\(title) not logged."
        case let .completed(physical, mental, notes):
            let base = "\(title) complete. Physical \(physical) of 5, mental \(mental) of 5, total \(physical + mental) of 10."
            if let notes, !notes.isEmpty { return "\(base) Note: \(notes)" }
            return base
        }
    }
}

struct CheckInHeatmapDay: Identifiable {
    let id: String
    let date: String
    let label: String
    let morningScore: Int?
    let afternoonScore: Int?
}

struct CheckInHeatmap: View {
    let days: [CheckInHeatmapDay]

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            heatmapRow(label: "AM", score: \.morningScore)
            heatmapRow(label: "PM", score: \.afternoonScore)
            dayLabels
        }
    }

    private func heatmapRow(label: String, score: KeyPath<CheckInHeatmapDay, Int?>) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .leading)
            ForEach(days) { day in
                CheckInHeatmapCell(score: day[keyPath: score])
                    .accessibilityLabel("\(label) \(day.label), \(day[keyPath: score].map { "\($0) out of 10" } ?? "not logged")")
            }
        }
    }

    private var dayLabels: some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: 18, height: 1)
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                Text(index % 7 == 0 || index == days.count - 1 ? day.label : "")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 8)
            }
        }
    }
}

struct CheckInHeatmapCell: View {
    let score: Int?

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(score.map { CheckInPresentation.scoreColor($0) } ?? Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(
                        score == nil ? Color.secondary.opacity(0.25) : Color.white.opacity(0.18),
                        lineWidth: 1
                    )
            }
            .frame(width: 8, height: 8)
    }
}

extension PeriodStatus {
    var combinedScore: Int? {
        if case let .completed(physical, mental, _) = self {
            return physical + mental
        }
        return nil
    }
}
