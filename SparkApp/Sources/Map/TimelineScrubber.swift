import SparkUI
import SwiftUI

/// Bottom-overlay scrubber that maps a 0...1 slider onto a 24h window. Shows
/// the currently-selected time in PT Mono and labels the day.
struct TimelineScrubber: View {
    @Binding var fraction: Double
    let anchorDay: Date

    var body: some View {
        VStack(spacing: SparkSpacing.sm) {
            HStack(alignment: .lastTextBaseline) {
                Text(anchorLabel)
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                Spacer(minLength: SparkSpacing.sm)
                Text(timeLabel)
                    .font(SparkTypography.monoBody)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            Slider(value: $fraction, in: 0...1)
                .tint(.sparkAccent)
                .accessibilityLabel("Timeline")
                .accessibilityValue(timeLabel)
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.vertical, SparkSpacing.md)
        .frame(maxWidth: .infinity)
        .sparkGlass(.roundedRect(SparkRadii.lg))
    }

    private var timeLabel: String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: anchorDay)
        let date = start.addingTimeInterval(24 * 60 * 60 * fraction)
        return Self.timeFormatter.string(from: date)
    }

    private var anchorLabel: String {
        if Calendar.current.isDateInToday(anchorDay) { return "Today" }
        if Calendar.current.isDateInYesterday(anchorDay) { return "Yesterday" }
        return Self.dateFormatter.string(from: anchorDay)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()
}
