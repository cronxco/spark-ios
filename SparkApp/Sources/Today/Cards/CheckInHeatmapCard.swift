import SparkKit
import SparkUI
import SwiftUI

/// The last 28 days of check-ins. Opens the history.
struct CheckInHeatmapCard: View {
    let historyVM: CheckInHistoryViewModel?
    @Binding var showHistory: Bool

    var body: some View {
        Button {
            showHistory = true
        } label: {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                HStack(spacing: SparkSpacing.sm) {
                    Text("Last 28 days")
                        .font(SparkTypography.captionStrong)
                    Spacer()
                    Text("\(completedDayCount) logged")
                        .font(SparkTypography.caption)
                    SparkGlyph(.forward, size: 10, relativeTo: .caption)
                }
                .foregroundStyle(.secondary)
                CheckInHeatmap(days: heatmapDays)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens your check-in history")
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
