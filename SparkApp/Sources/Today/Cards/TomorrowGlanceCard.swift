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
                HStack {
                    Text("Tomorrow at a glance")
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.tertiary)
                }

                Text(ahead.headline)
                    .font(SparkTypography.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let bedBy = ahead.sleepTarget?.bedByDate {
                    Label("In bed by \(bedBy.formatted(date: .omitted, time: .shortened))", systemImage: "bed.double.fill")
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(Color.sparkOcean)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SparkSpacing.lg)
            .sparkGlass(.roundedRect(SparkRadii.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tomorrow at a glance. \(ahead.headline)")
        .accessibilityHint("Opens tomorrow")
    }
}
