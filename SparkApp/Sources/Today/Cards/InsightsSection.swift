import SparkKit
import SparkUI
import SwiftUI

/// The day's comparisons, one line each: this week against the last four,
/// today against what is usual. Hidden when there are none.
struct InsightsSection: View {
    let insights: [DayInsight]

    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Insights")
                ForEach(insights) { insight in
                    InsightRow(insight: insight)
                }
            }
        }
    }
}

struct InsightRow: View {
    let insight: DayInsight

    var body: some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md, tint: tint?.opacity(0.08)) {
            HStack(alignment: .top, spacing: SparkSpacing.md) {
                SparkGlyph(insight.isDown ? .decrease : .increase, size: 15)
                    .foregroundStyle(tint ?? .secondary)
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.displayName ?? insight.metric ?? "Insight")
                        .font(SparkTypography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(insight.sentence)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Neutral stays uncoloured: a move with no good or bad side is not a warning.
    private var tint: Color? {
        switch insight.valence {
        case .good: .sparkSuccess
        case .bad: .sparkError
        case .neutral: nil
        }
    }
}
