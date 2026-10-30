import SparkKit
import SparkUI
import SwiftUI

/// Flint's active threads, each showing what it is waiting for.
///
/// Not a summary of the thread — the closing sentence of its running summary,
/// which is the part written to say what would move it on. That is the only
/// part of a thread worth a home screen: it is the assistant's attention,
/// stated.
///
/// Dormant threads collapse to a single line with the next review date, so
/// they are visible without taking space from the live ones. Tapping it opens
/// the thread that date belongs to.
struct ThreadsStrip: View {
    let topics: [FlintTopic]
    let onOpen: (FlintTopic) -> Void

    private var active: [FlintTopic] {
        topics.filter { $0.status?.isActive == true }
    }

    private var dormant: [FlintTopic] {
        topics.filter { $0.status == .dormant }
    }

    /// The dormant thread due back soonest, so the row's date and the thread
    /// it opens are the same one. Falls back to the first dormant thread when
    /// none has a review ahead of it.
    private var nextDormant: FlintTopic? {
        let upcoming = dormant.filter { ($0.nextReviewAt ?? .distantPast) >= .now }
        return upcoming.min { ($0.nextReviewAt ?? .distantFuture) < ($1.nextReviewAt ?? .distantFuture) }
            ?? dormant.first
    }

    var body: some View {
        if !active.isEmpty || !dormant.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Threads", style: .dayHeading)

                if !active.isEmpty {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: SparkSpacing.md) {
                            ForEach(active) { topic in
                                Button { onOpen(topic) } label: {
                                    ThreadCard(topic: topic)
                                }
                                .buttonStyle(.plain)
                                .containerRelativeFrame(.horizontal) { width, _ in
                                    active.count > 1 ? width - SparkSpacing.xl : width
                                }
                            }
                        }
                        .padding(.vertical, SparkSpacing.sm)
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollIndicators(.hidden)
                    // Keep the adjacent-card peek visible beyond the
                    // horizontal scroll viewport.
                    .scrollClipDisabled()
                    .scrollDisabled(active.count <= 1)
                }

                if !dormant.isEmpty {
                    dormantRow
                }
            }
        }
    }

    private var dormantRow: some View {
        Button {
            if let nextDormant { onOpen(nextDormant) }
        } label: {
            HStack(spacing: SparkSpacing.sm) {
                Text(dormantSummary)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: SparkSpacing.sm)
                SparkGlyph(.forward, size: 10, relativeTo: .caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, SparkSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var dormantSummary: String {
        let count = "\(dormant.count) dormant"
        guard let next = nextDormant?.nextReviewAt, next >= .now else { return count }
        return "\(count), next review \(Self.reviewDate.string(from: next))"
    }

    private static let reviewDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()
}

private struct ThreadCard: View {
    let topic: FlintTopic

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text(Self.kindLabel(topic.kind))
                .font(SparkTypography.captionStrong)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(topic.title)
                .font(SparkTypography.bodyStrong)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let watching = topic.watchingFor {
                Text(watching)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkContentSurface(radius: SparkRadii.md)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the thread")
    }

    /// The kind in sentence case, as the card's eyebrow.
    private static func kindLabel(_ kind: FlintTopicKind?) -> String {
        guard let raw = kind?.rawValue, let first = raw.first else { return "Thread" }
        return first.uppercased() + raw.dropFirst()
    }
}
