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
                SectionLabel("Threads")

                if !active.isEmpty {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: SparkSpacing.md) {
                            ForEach(active) { topic in
                                Button { onOpen(topic) } label: {
                                    ThreadCard(topic: topic)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollIndicators(.hidden)
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
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, SparkSpacing.md)
            .padding(.vertical, SparkSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 44)
            .sparkGlass(.capsule)
        }
        .buttonStyle(.plain)
    }

    private var dormantSummary: String {
        let count = "\(dormant.count) dormant"
        guard let next = nextDormant?.nextReviewAt, next >= .now else { return count }
        return "\(count) · next review \(Self.reviewDate.string(from: next))"
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
            HStack(spacing: 6) {
                Circle()
                    .fill(Self.tint(for: topic.kind))
                    .frame(width: 6, height: 6)
                Text(topic.kind?.rawValue ?? "thread")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

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
        .frame(width: 262, alignment: .leading)
        .sparkGlass(.roundedRect(SparkRadii.md))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the thread")
    }

    private static func tint(for kind: FlintTopicKind?) -> Color {
        switch kind {
        case .strategic: .sparkTagPerson
        case .thematic: .domainActivity
        case .tactical: .domainKnowledge
        case nil: .secondary
        }
    }
}
