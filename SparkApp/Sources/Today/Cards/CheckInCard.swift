import SparkKit
import SparkUI
import SwiftUI

struct CheckInCard: View {
    let date: Date
    let status: CheckInDayStatus
    let onTapMorning: () -> Void
    let onTapAfternoon: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                CheckInPeriodSummaryRow(
                    title: "Morning Check-in",
                    status: status.morning,
                    onTap: onTapMorning
                )
                if showsAfternoonRow {
                    Divider()
                    CheckInPeriodSummaryRow(
                        title: "Afternoon Check-in",
                        status: status.afternoon,
                        onTap: onTapAfternoon
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var showsAfternoonRow: Bool {
        let calendar = Calendar.current
        if calendar.isDateInToday(date), calendar.component(.hour, from: .now) < 12 {
            return false
        }
        return true
    }
}
