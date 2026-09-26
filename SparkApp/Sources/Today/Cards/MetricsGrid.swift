import SparkKit
import SparkUI
import SwiftUI

/// Sleep, activity, readiness and money, in one grammar.
///
/// Two columns when each card has room for its supporting values; one on a
/// narrow layout or at larger Dynamic Type sizes.
struct MetricsGrid: View {
    let metrics: DayMetrics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isNarrow = false

    // Two cards need at least 192 points each for their supporting rows,
    // plus the gap between them. Below that, keep the values in one column.
    private nonisolated static let minimumTwoColumnWidth: CGFloat = 400

    private var columns: [GridItem] {
        let count = isNarrow || dynamicTypeSize >= .xxxLarge ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: SparkSpacing.lg), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SectionLabel("Metrics", style: .dayHeading)

            LazyVGrid(columns: columns, spacing: SparkSpacing.lg) {
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
        .onGeometryChange(for: Bool.self) { geometry in
            geometry.size.width < Self.minimumTwoColumnWidth
        } action: { narrow in
            isNarrow = narrow
        }
    }
}
