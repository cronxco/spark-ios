import SparkKit
import SparkUI
import SwiftUI

/// A thread, opened from the Day tab.
///
/// The Flint tab has the full thread screen with its source mentions; this is
/// the Day tab's read-only look at the same thing, because the Day tab has its
/// own navigation stack and pushing a Flint route from it is not possible.
struct ThreadDetailSheet: View {
    let topic: FlintTopic
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    header

                    if let content = topic.content, !content.isEmpty {
                        Text(content)
                            .font(SparkTypography.longFormBodySmall)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 0) {
                        if let review = topic.nextReviewAt {
                            InspectorRow("Next review", isMono: true) {
                                Text(Self.date.string(from: review))
                            }
                        }
                        if let touched = topic.lastTouchedAt {
                            InspectorRow("Last moved", isMono: true) {
                                Text(Self.date.string(from: touched))
                            }
                        }
                        if let seen = topic.firstSeenAt {
                            InspectorRow("First seen", isMono: true) {
                                Text(Self.date.string(from: seen))
                            }
                        }
                    }
                    .sparkGlass(.roundedRect(SparkRadii.md))
                }
                .padding(SparkSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .sparkAppBackground()
            .navigationTitle("Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text(topic.title)
                .font(SparkFonts.display(.title2, weight: .bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: SparkSpacing.sm) {
                if let kind = topic.kind {
                    Text(kind.rawValue)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
                if let status = topic.status {
                    Text(status.rawValue)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private static let date: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
