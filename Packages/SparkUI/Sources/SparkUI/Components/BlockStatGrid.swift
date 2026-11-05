import SparkKit
import SwiftUI

/// A block's readings as label-over-value pairs (design language §8): up to
/// eight fields, as many to a line as fit, each at least 72pt wide. Labels
/// are captions in secondary ink; values are body semibold so the card's
/// hero value stays the loudest thing on it.
public struct BlockStatGrid: View {
    let facts: [BlockFact]

    public init(facts: [BlockFact]) {
        self.facts = facts
    }

    public var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72), spacing: SparkSpacing.md, alignment: .topLeading)],
            alignment: .leading,
            spacing: SparkSpacing.md
        ) {
            ForEach(facts.prefix(8)) { fact in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.label)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                    Text(fact.value)
                        .font(SparkTypography.bodyStrong)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
