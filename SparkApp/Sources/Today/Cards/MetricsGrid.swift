import SparkKit
import SparkUI
import SwiftUI

/// Sleep, activity, readiness and money, in one grammar.
///
/// Two columns at ordinary type sizes; one at accessibility sizes, where two
/// 173pt cards cannot hold a figure and its two supporting values without
/// wrapping into a ragged grid.
struct MetricsGrid: View {
    let metrics: DayMetrics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: SparkSpacing.md), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SectionLabel("Metrics")

            LazyVGrid(columns: columns, spacing: SparkSpacing.md) {
                ForEach(metrics.cards) { card in
                    BaselineMetricCard(
                        label: card.label,
                        tint: card.tint,
                        reading: card.reading,
                        fill: card.fill,
                        baseline: card.baseline,
                        isFlagged: card.isFlagged,
                        primary: card.primary,
                        secondary: card.secondary
                    )
                }
            }
        }
    }
}
