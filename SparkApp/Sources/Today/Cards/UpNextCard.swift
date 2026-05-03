import SparkUI
import SwiftUI

struct UpNextCard: View {
    let event: KnowledgeSnapshot.CalendarEvent

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                GlassCardHeader(
                    icon: "calendar",
                    tint: .domainKnowledge,
                    title: "Up next"
                )

                Text(event.title)
                    .font(SparkTypography.bodyStrong)
                    .lineLimit(2)

                HStack(spacing: SparkSpacing.sm) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(event.start) → \(event.end)")
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                    if let location = event.location {
                        Text("·").foregroundStyle(.secondary)
                        Image(systemName: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(location)
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("From \(event.start) to \(event.end)\(event.location.map { " at \($0)" } ?? "")")
            }
        }
    }
}
