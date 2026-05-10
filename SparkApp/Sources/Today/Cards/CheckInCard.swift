import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct CheckInCard: View {
    let status: CheckInDayStatus
    let onTapMorning: () -> Void
    let onTapAfternoon: () -> Void
    @Binding var showHistory: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var historyDays: [DayDotData] = []
    @State private var streakCount: Int = 0

    private var isMorning: Bool {
        Calendar.current.component(.hour, from: .now) < 12
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                GlassCardHeader(
                    icon: "heart.text.clipboard",
                    tint: .sparkAccent,
                    title: "Check-ins"
                )
                Divider()
                    .padding(.vertical, SparkSpacing.sm)
                morningRow
                if !isMorning {
                    afternoonRow
                }
                Divider()
                    .padding(.vertical, SparkSpacing.sm)
                streakSection
            }
        }
        .accessibilityElement(children: .contain)
        .task(id: status.stableKey) {
            await loadHistory()
        }
    }

    // MARK: - Period rows

    @ViewBuilder
    private var morningRow: some View {
        switch status.morning {
        case let .completed(physical, mental, notes):
            CheckInPeriodRow(label: "Morning", status: .completed(physical: physical, mental: mental, notes: notes), onTap: {})
        case .pending where isMorning:
            CheckInPeriodRow(label: "Morning", status: .pending, onTap: onTapMorning)
        case .pending:
            MissedPeriodRow(label: "Morning")
        }
    }

    @ViewBuilder
    private var afternoonRow: some View {
        CheckInPeriodRow(label: "Afternoon", status: status.afternoon, onTap: onTapAfternoon)
    }

    // MARK: - Streak section

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack {
                SectionLabel("CHECK-IN STREAK")
                Spacer()
                Text("\(streakCount) day\(streakCount == 1 ? "" : "s")")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(historyDays) { day in
                    DayDotView(data: day)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showHistory = true }
    }

    // MARK: - History loading

    private func loadHistory() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var days: [DayDotData] = []

        for offset in stride(from: 13, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dateKey = Self.isoDate(day)
            let label = String(calendar.component(.day, from: day))

            let descriptor = FetchDescriptor<CachedCheckIn>(
                predicate: #Predicate { $0.date == dateKey }
            )
            let rows = (try? modelContext.fetch(descriptor)) ?? []
            let morningDone = rows.first(where: { $0.period == "morning" })?.completed == true
            let afternoonDone = rows.first(where: { $0.period == "afternoon" })?.completed == true

            days.append(DayDotData(
                id: dateKey,
                label: label,
                morningDone: morningDone,
                afternoonDone: afternoonDone
            ))
        }

        historyDays = days

        var streak = 0
        for day in days.reversed() {
            if day.morningDone || day.afternoonDone {
                streak += 1
            } else {
                break
            }
        }
        streakCount = streak
    }

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Period row

private struct CheckInPeriodRow: View {
    let label: String
    let status: PeriodStatus
    let onTap: () -> Void

    var body: some View {
        Group {
            switch status {
            case .pending:
                Button(action: onTap) { rowContent }
                    .buttonStyle(.plain)
            case .completed:
                rowContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var rowContent: some View {
        HStack {
            Text(label)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.primary)
            Spacer()
            switch status {
            case .pending:
                Text("tap to log →")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            case let .completed(physical, mental, _):
                ScoreDots(physical: physical, mental: mental)
            }
        }
        .padding(.vertical, SparkSpacing.xs)
    }

    private var accessibilityLabel: String {
        switch status {
        case .pending:
            return "\(label) check-in pending. Tap to log."
        case let .completed(physical, mental, notes):
            let base = "\(label) check-in complete. Physical \(physical) of 5, mental \(mental) of 5."
            if let notes, !notes.isEmpty { return "\(base) Note: \(notes)" }
            return base
        }
    }
}

// MARK: - Missed period row

private struct MissedPeriodRow: View {
    let label: String

    var body: some View {
        HStack {
            Text(label)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(Color.secondary.opacity(0.5))
            Spacer()
            Text("—")
                .font(SparkTypography.monoSmall)
                .foregroundStyle(Color.secondary.opacity(0.4))
        }
        .padding(.vertical, SparkSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) check-in missed")
    }
}

// MARK: - Score dots

private struct ScoreDots: View {
    let physical: Int
    let mental: Int

    private var combined: Int { physical + mental }

    private var score: Int {
        max(1, min(5, (physical + mental + 1) / 2))
    }

    private var tint: Color {
        switch combined {
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

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .frame(width: 7, height: 7)
                    .foregroundStyle(i <= score ? tint : tint.opacity(0.2))
            }
        }
    }
}

// MARK: - Day dot

private struct DayDotData: Identifiable {
    let id: String
    let label: String
    let morningDone: Bool
    let afternoonDone: Bool
}

private struct DayDotView: View {
    let data: DayDotData

    private var dotColor: Color {
        if data.morningDone && data.afternoonDone { return .sparkAccent }
        if data.morningDone || data.afternoonDone { return .sparkWarning }
        return .clear
    }

    private var strokeColor: Color {
        if data.morningDone || data.afternoonDone { return .clear }
        return Color.secondary.opacity(0.3)
    }

    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(dotColor)
                .overlay(Circle().strokeBorder(strokeColor, lineWidth: 1))
                .frame(width: 10, height: 10)
            Text(data.label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if data.morningDone && data.afternoonDone { return "Day \(data.label), both check-ins complete" }
        if data.morningDone || data.afternoonDone { return "Day \(data.label), one check-in complete" }
        return "Day \(data.label), no check-in"
    }
}

// MARK: - Stable key helper

private extension CheckInDayStatus {
    var stableKey: String {
        let m: String = { if case .pending = morning { return "p" }; return "c" }()
        let a: String = { if case .pending = afternoon { return "p" }; return "c" }()
        return "\(m)\(a)"
    }
}
