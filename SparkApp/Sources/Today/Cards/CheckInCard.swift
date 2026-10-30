import SparkKit
import SparkUI
import SwiftUI

/// The day's check-ins and the last 28 days, in one card under one heading.
struct CheckInsSection: View {
    let date: Date
    let status: CheckInDayStatus
    let historyVM: CheckInHistoryViewModel?
    @Binding var showHistory: Bool
    let onTapMorning: () -> Void
    let onTapAfternoon: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SectionLabel("Check-ins", style: .dayHeading)

            GlassCard {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    CheckInCard(
                        date: date,
                        status: status,
                        onTapMorning: onTapMorning,
                        onTapAfternoon: onTapAfternoon
                    )
                    CheckInHeatmapCard(historyVM: historyVM, showHistory: $showHistory)
                }
            }
        }
    }
}

/// The morning and afternoon rows.
struct CheckInCard: View {
    let date: Date
    let status: CheckInDayStatus
    let onTapMorning: () -> Void
    let onTapAfternoon: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            CheckInPeriodSummaryRow(
                title: "Morning check-in",
                status: status.morning,
                onTap: onTapMorning
            )
            if showsAfternoonRow {
                Divider()
                CheckInPeriodSummaryRow(
                    title: "Afternoon check-in",
                    status: status.afternoon,
                    onTap: onTapAfternoon
                )
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
