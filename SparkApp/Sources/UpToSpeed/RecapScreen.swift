import SparkKit
import SparkUI
import SwiftUI

/// Everything already caught up on today, offered past the end of the flow.
///
/// Up to Speed is one-way by design: a card swiped past is gone, and there is
/// no web equivalent to find it in. That makes an accidental swipe — or a
/// mis-tapped "Not worth flagging" — permanent. This screen is the way back:
/// each row can be returned to the unread queue.
struct RecapScreen: View {
    let viewModel: UpToSpeedViewModel
    var isActive: Bool = true

    var body: some View {
        StoryScreenScaffold(label: "Earlier today", isActive: isActive) {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                Text(headline)
                    .font(SparkTypography.hero)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Anything here can go back in the queue.")
                    .font(SparkTypography.longFormBodySmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                GlassCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.recapItems.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Divider().opacity(0.15)
                            }
                            RecapRow(item: item, viewModel: viewModel)
                        }
                    }
                }
            }
        }
    }

    private var headline: String {
        let count = viewModel.recapItems.count
        return count == 1 ? "One thing already seen." : "\(count) things already seen."
    }
}

private struct RecapRow: View {
    let item: UpToSpeedItem
    let viewModel: UpToSpeedViewModel

    @State private var isRestoring = false

    private var isBusy: Bool { isRestoring || viewModel.unmarkingIDs.contains(item.id) }

    var body: some View {
        HStack(alignment: .top, spacing: SparkSpacing.md) {
            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                Text(title)
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: SparkSpacing.sm)

            Button {
                isRestoring = true
                Task {
                    await viewModel.unmark(item)
                    isRestoring = false
                }
            } label: {
                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Restore")
                        .font(SparkTypography.captionStrong)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.spark700)
            .disabled(isBusy)
            .accessibilityLabel("Restore \(title)")
            .accessibilityHint("Puts this back in your catch-up queue")
        }
        .padding(SparkSpacing.lg)
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch item.payload {
        case .flintDigest(let summary):
            return summary.title ?? "Digest"
        case .newsSummary(let news):
            return news.title
        case .anomaly(let anomaly):
            return anomaly.displayName ?? "Something unusual"
        case .checkIn(let summary):
            return "\(summary.period.rawValue.capitalized) check-in"
        }
    }

    /// Says both what the item was and how it left the queue — "dismissed" and
    /// "read" are different things, and only the first needs undoing urgently.
    private var subtitle: String {
        var parts: [String] = [kindLabel]

        if case .anomaly(let anomaly) = item.payload, anomaly.acknowledgedAt != nil {
            parts.append("dismissed")
        } else {
            parts.append("read")
        }

        if let seen = UpToSpeedVisibility(now: .now, calendar: .current).seenAt(item) {
            parts.append(seen.formatted(date: .omitted, time: .shortened))
        }

        return parts.joined(separator: " · ")
    }

    private var kindLabel: String {
        switch item.payload {
        case .flintDigest: "Briefing"
        case .newsSummary(let news): news.source.capitalized
        case .anomaly: "Unusual"
        case .checkIn: "Check-in"
        }
    }
}
