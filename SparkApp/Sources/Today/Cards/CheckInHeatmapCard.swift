import SparkKit
import SparkUI
import SwiftUI

struct CheckInHeatmapCard: View {
    let historyVM: CheckInHistoryViewModel?
    @Binding var showHistory: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                HStack {
                    SectionLabel("Last 28 days")
                    Spacer()
                    Text("\(completedDayCount) logged")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
                CheckInHeatmap(days: heatmapDays)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showHistory = true }
    }

    private var completedDayCount: Int {
        historyVM?.days.filter { $0.morning.completed || $0.afternoon.completed }.count ?? 0
    }

    private var heatmapDays: [CheckInHeatmapDay] {
        (historyVM?.days ?? []).reversed().map { day in
            CheckInHeatmapDay(
                id: day.date,
                date: day.date,
                label: String(Int(day.date.suffix(2)) ?? 0),
                morningScore: day.morning.combined,
                afternoonScore: day.afternoon.combined
            )
        }
    }
}
