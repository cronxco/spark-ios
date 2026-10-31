import SparkKit
import SparkUI
import SwiftUI

/// Sleep, activity, readiness and money, in one grammar.
///
/// Two columns of compact cards (`docs/design-language.md` section 7.2); one
/// on a narrow layout or at larger Dynamic Type sizes.
struct MetricsGrid: View {
    let metrics: DayMetrics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isNarrow = false

    // Two cards need room for a 64pt ring and its comparison line, plus the
    // gap between them. Below that, keep the values in one column.
    private nonisolated static let minimumTwoColumnWidth: CGFloat = 320

    private var columns: [GridItem] {
        let count = isNarrow || dynamicTypeSize >= .xxxLarge ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: SparkSpacing.md), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SectionLabel("Metrics", style: .dayHeading)

            LazyVGrid(columns: columns, spacing: SparkSpacing.md) {
                ForEach(metrics.cards) { card in
                    PeekableMetricCard(card: card)
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

/// A compact metric that opens a peek card on a tap, with the figures the
/// card leaves out (sleep duration and efficiency, steps and active energy,
/// resting heart rate, balance) and a button to its Explore section.
private struct PeekableMetricCard: View {
    let card: DayMetrics.Card

    @Environment(AppModel.self) private var appModel
    @State private var isPeeking = false

    var body: some View {
        Button {
            isPeeking.toggle()
        } label: {
            DayMetricCard(card: card)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows more figures")
        .sparkPeek(isPresented: $isPeeking) {
            PeekCard(
                icon: card.icon,
                tint: EntityPresentation.tint(domain: card.domain),
                eyebrow: card.domain.capitalized,
                title: card.label,
                facts: card.peekFacts,
                action: PeekCard.Action(card.exploreDestination == .exploreMoney ? "Open Money" : "Open Health") {
                    isPeeking = false
                    appModel.pendingDestination = card.exploreDestination
                }
            )
        }
    }
}

/// One compact metric: the domain glyph and label, the reading as a ring for
/// a score or a value over its against-the-mean bar, and one comparison line.
struct DayMetricCard: View {
    let card: DayMetrics.Card

    private var tint: Color { EntityPresentation.tint(domain: card.domain) }
    private var hero: Color { .sparkHero(domain: card.domain) }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.xs) {
                SparkGlyph(card.icon, size: 13, relativeTo: .caption)
                    .foregroundStyle(tint)
                Text(card.label)
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            reading
                .frame(maxWidth: .infinity, alignment: card.scoreFraction == nil ? .leading : .center)

            Spacer(minLength: 0)

            if let comparison = card.comparison {
                ComparisonLine(comparison: comparison)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(SparkSpacing.md)
        .sparkContentSurface(radius: SparkRadii.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.accessibilityLabel)
    }

    @ViewBuilder
    private var reading: some View {
        switch card.reading {
        case .waiting(let reason):
            Text(reason)
                .font(SparkTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .value(let text, _):
            if let fraction = card.scoreFraction {
                ScoreRing(fraction: fraction, text: text, tint: tint, diameter: 64, threshold: 0.85, valueColor: hero)
            } else {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xxs) {
                        Text(text)
                            .font(SparkTypography.compactValue)
                            .foregroundStyle(hero)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let unit = card.unit {
                            Text(unit)
                                .font(SparkTypography.compactUnit)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if card.meanBar.fill != nil {
                        MeanBar(geometry: card.meanBar, tint: tint)
                    }
                }
            }
        }
    }
}

/// The against-the-mean bar (section 8): today's fill on a track that runs to
/// 1.5× the mean, with a marker at the mean.
private struct MeanBar: View {
    let geometry: BarGeometry
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                Capsule().fill(tint.opacity(0.15))
                    .frame(width: width, height: 6)
                    .offset(y: 4)
                Capsule().fill(tint)
                    .frame(width: width * (geometry.fill ?? 0), height: 6)
                    .offset(y: 4)
                if let mean = geometry.baseline {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.primary)
                        .frame(width: 2, height: 14)
                        .offset(x: width * mean - 1)
                    Text("Avg")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .frame(width: 40)
                        .offset(x: width * mean - 20, y: 14)
                }
            }
        }
        .frame(height: 28)
        .accessibilityHidden(true)
    }
}

/// Arrow, amount with unit, direction word and window (section 3.4), in the
/// polarity colour; neutral when the change is inside the usual range.
private struct ComparisonLine: View {
    let comparison: MetricComparison

    private var color: Color {
        switch comparison.isGood {
        case true?: .sparkSuccess
        case false?: .sparkError
        case nil: .secondary
        }
    }

    private var icon: SparkIcon? {
        switch comparison.direction {
        case .up?: .increase
        case .down?: .decrease
        case .steady?: .steady
        case nil: nil
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
            if let icon {
                SparkGlyph(icon, size: 11, relativeTo: .caption)
            }
            Text(comparison.text)
                .font(SparkTypography.caption)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(color)
    }
}
