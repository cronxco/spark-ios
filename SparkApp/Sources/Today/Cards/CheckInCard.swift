import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct CheckInCard: View {
    let date: Date
    let status: CheckInDayStatus
    let onTapMorning: () -> Void
    let onTapAfternoon: () -> Void
    @Binding var showHistory: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var historyDays: [CheckInHeatmapDay] = []

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    CheckInPeriodSummaryRow(
                        title: "Morning Check-in",
                        status: status.morning,
                        onTap: onTapMorning
                    )
                    if showsAfternoonRow {
                        CheckInPeriodSummaryRow(
                            title: "Afternoon Check-in",
                            status: status.afternoon,
                            onTap: onTapAfternoon
                        )
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    HStack {
                        SectionLabel("LAST 28 DAYS")
                        Spacer()
                        Text("\(completedDayCount) logged")
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                    CheckInHeatmap(days: historyDays)
                }
                .contentShape(Rectangle())
                .onTapGesture { showHistory = true }
            }
        }
        .accessibilityElement(children: .contain)
        .task(id: "\(Self.isoDate(date))-\(status.stableKey)") {
            await loadHistory()
        }
    }

    private var completedDayCount: Int {
        historyDays.filter { $0.morningScore != nil || $0.afternoonScore != nil }.count
    }

    private var showsAfternoonRow: Bool {
        let calendar = Calendar.current
        if calendar.isDateInToday(date), calendar.component(.hour, from: .now) < 12 {
            return false
        }
        return true
    }

    private func loadHistory() async {
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: date)
        var days: [CheckInHeatmapDay] = []

        for offset in stride(from: 27, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: endDay) else { continue }
            let dateKey = Self.isoDate(day)
            let label = String(calendar.component(.day, from: day))

            let descriptor = FetchDescriptor<CachedCheckIn>(
                predicate: #Predicate { $0.date == dateKey }
            )
            let rows = (try? modelContext.fetch(descriptor)) ?? []
            let morning = rows.first(where: { $0.period == "morning" && $0.completed })
            let afternoon = rows.first(where: { $0.period == "afternoon" && $0.completed })

            days.append(CheckInHeatmapDay(
                id: dateKey,
                date: dateKey,
                label: label,
                morningScore: combinedScore(for: morning),
                afternoonScore: combinedScore(for: afternoon)
            ))
        }

        historyDays = days
    }

    private func combinedScore(for row: CachedCheckIn?) -> Int? {
        guard let physical = row?.physical, let mental = row?.mental else { return nil }
        return physical + mental
    }

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

private extension CheckInDayStatus {
    var stableKey: String {
        func key(_ status: PeriodStatus) -> String {
            switch status {
            case .pending:
                return "p"
            case let .completed(physical, mental, _):
                return "c\(physical)-\(mental)"
            }
        }

        return "\(key(morning))-\(key(afternoon))"
    }
}
