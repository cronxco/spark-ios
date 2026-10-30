import SparkKit
import SparkUI
import SwiftUI

/// "Tomorrow at a glance" on the evening Today page: the server's line about
/// tomorrow, the first commitment and the weather. The whole card opens the
/// Looking ahead page.
struct TomorrowGlanceCard: View {
    let ahead: DayAhead
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                HStack(spacing: SparkSpacing.xs + 2) {
                    SparkGlyph(.calendarEvent, size: 12, relativeTo: .caption)
                    Text("Tomorrow at a glance")
                        .font(SparkTypography.captionStrong)
                    Spacer()
                    SparkGlyph(.forward, size: 11, relativeTo: .caption)
                }
                .foregroundStyle(.secondary)

                Text(ahead.headline)
                    .font(SparkTypography.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let bedBy = ahead.sleepTarget?.bedByDate {
                    HStack(spacing: SparkSpacing.sm) {
                        SparkGlyph(.bedtime, size: 14, relativeTo: .caption)
                            .foregroundStyle(Color.domainHealth)
                        Text("In bed by \(Self.time.string(from: bedBy))")
                            .font(SparkTypography.captionStrong)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SparkSpacing.lg)
            .sparkContentSurface(radius: SparkRadii.lg)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tomorrow at a glance. \(ahead.headline)")
        .accessibilityHint("Opens tomorrow")
    }

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        return f
    }()
}
