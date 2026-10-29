import SparkKit
import SwiftUI

public extension EventKind {
    /// The glyph for each kind (design language §6). `.generic` falls back
    /// to the event's domain.
    func systemImage(domain: String?) -> String {
        switch self {
        case .sleepScore, .sleepDuration: "moon.zzz.fill"
        case .readinessScore: "gauge.with.needle"
        case .activityScore: "figure.run"
        case .steps: "figure.walk"
        case .exerciseTime: "clock"
        case .generic: EntityPresentation.icon(domain: domain)
        }
    }
}

/// The one view that draws an event as a card.
///
/// Only the `compact` size exists so far, for the cards under a Flint
/// briefing paragraph in Up to Speed (design language §7.3): an eyebrow with
/// glyph and short label, the live value, and one context line. Layout
/// choices come from `EventKind`, so a kind added there is picked up here.
/// The card sits on the content surface, not glass (§5.3).
public struct EventCard: View {
    public enum Size: Sendable {
        /// Up to three across under a paragraph: eyebrow, value, context.
        case compact
    }

    let card: LinkedEventCard
    let size: Size

    @Environment(\.colorSchemeContrast) private var contrast

    public init(_ card: LinkedEventCard, size: Size = .compact) {
        self.card = card
        self.size = size
    }

    private var kind: EventKind { card.kind }
    private var fill: Color { EntityPresentation.tint(domain: card.event.domain) }

    public var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            eyebrow
            Spacer(minLength: 0)
            hero
            if let line = contextLine {
                contextView(line)
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous)
                .fill(Color.sparkElevated)
        )
        .overlay {
            if contrast == .increased {
                RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.35), lineWidth: 1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    private var eyebrow: some View {
        HStack(spacing: SparkSpacing.xs) {
            Image(systemName: kind.systemImage(domain: card.event.domain))
                .font(.caption)
                .foregroundStyle(fill)
            Text(card.label)
                .font(SparkTypography.captionStrong)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var hero: some View {
        if let maximum = kind.ringMaximum, let live = card.liveValue {
            ScoreRing(value: live, maximum: maximum, label: card.heroValue, fill: fill)
                .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                Text(card.heroValue)
                    .font(SparkFonts.display(.title2, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let fraction = card.meanBarFraction {
                    MeanBar(fraction: fraction, fill: fill)
                }
            }
        }
    }

    private struct ContextLine {
        let text: String
        let systemImage: String
        let tint: Color
    }

    private var contextLine: ContextLine? {
        if let updated = card.updatedFromText {
            return ContextLine(text: updated, systemImage: "clock.arrow.circlepath", tint: .secondary)
        }
        guard let context = card.context else { return nil }

        // §3.4: the arrow always points the way the value moved; only its
        // colour depends on whether that is good, bad or within the usual.
        let systemImage = switch context.direction {
        case .flat: "arrow.right"
        case .up: "arrow.up"
        case .down: "arrow.down"
        }
        let tint: Color = switch context.valence {
        case .good: .sparkSuccess
        case .bad: .sparkError
        case .neutral: .secondary
        }
        return ContextLine(text: context.text, systemImage: systemImage, tint: tint)
    }

    private func contextView(_ line: ContextLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xxs) {
            Image(systemName: line.systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(line.tint)
            Text(line.text)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One VoiceOver element: "Sleep score, 66, 12 below 30d trend".
    /// Scores carry "out of 100" here and nowhere else (§9).
    private var accessibilityText: String {
        var parts = [card.label]
        if let maximum = kind.ringMaximum, card.liveValue != nil {
            parts.append("\(card.heroValue) out of \(Int(maximum))")
        } else {
            parts.append(card.heroValue)
        }
        if let line = contextLine { parts.append(line.text) }
        if card.meanBarFraction != nil, let mean = card.context?.mean {
            parts.append("30-day average \(kind.heroValue(mean, unit: card.event.unit, displayValue: nil))")
        }
        return parts.joined(separator: ", ")
    }
}

/// A score drawn as a 64pt ring with the number inside and a short tick at
/// 85, Oura's "excellent" (design language §7.3). Proportions follow the
/// spec's 84-unit SVG: radius 36, stroke 8.
struct ScoreRing: View {
    let value: Double
    let maximum: Double
    let label: String
    let fill: Color

    static let diameter: CGFloat = 64
    static let excellent: Double = 85

    private var scale: CGFloat { Self.diameter / 84 }
    private var lineWidth: CGFloat { 8 * scale }
    private var progress: Double { min(max(value / maximum, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(fill.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Capsule()
                .fill(Color.primary)
                .frame(width: 2 * scale, height: 10 * scale)
                .offset(y: -(Self.diameter / 2 - lineWidth / 2))
                .rotationEffect(.degrees(Self.excellent / maximum * 360))
            Text(label)
                .font(SparkFonts.display(.title3, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, lineWidth + 2)
        }
        .padding(lineWidth / 2)
        .frame(width: Self.diameter, height: Self.diameter)
        .accessibilityHidden(true)
    }
}

/// A value against the reader's 30d average (design language §8): a thin
/// track that runs to 1.5× the mean, with a vertical Avg marker at the mean.
struct MeanBar: View {
    let fraction: Double
    let fill: Color

    /// Label on top, then the marker standing 6pt proud of the track.
    private static let barHeight: CGFloat = 6
    private static let barTop: CGFloat = 18
    private static let markerTop: CGFloat = 12
    private static let totalHeight: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let markerX = width * LinkedEventCard.meanBarMarker
            let barY = Self.barTop + Self.barHeight / 2

            Capsule()
                .fill(Color.primary.opacity(0.1))
                .frame(width: width, height: Self.barHeight)
                .position(x: width / 2, y: barY)
            Capsule()
                .fill(fill)
                .frame(width: max(Self.barHeight, width * fraction), height: Self.barHeight)
                .position(x: max(Self.barHeight, width * fraction) / 2, y: barY)
            Capsule()
                .fill(Color.primary)
                .frame(width: 2, height: Self.totalHeight - Self.markerTop)
                .position(x: markerX, y: (Self.markerTop + Self.totalHeight) / 2)
            Text("Avg")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
                .position(x: markerX, y: Self.markerTop / 2)
        }
        .frame(height: Self.totalHeight)
        .accessibilityHidden(true)
    }
}

/// Up to three compact event cards under a paragraph, in the order the prose
/// mentions them. Past three, the third slot reads "+N more" and reveals the
/// rest (design language §7.3). Tapping a card opens its event.
public struct EventCardRow: View {
    let cards: [LinkedEventCard]
    let onOpen: (LinkedEventCard) -> Void

    @State private var isExpanded = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(_ cards: [LinkedEventCard], onOpen: @escaping (LinkedEventCard) -> Void) {
        self.cards = cards
        self.onOpen = onOpen
    }

    private var visible: [LinkedEventCard] {
        isExpanded || cards.count <= 3 ? cards : Array(cards.prefix(2))
    }

    private var hiddenCount: Int { cards.count - visible.count }

    /// Two or three across; one column at accessibility text sizes, where
    /// each card grows to fit its text (§11).
    private var columnCount: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : min(3, max(2, cards.count))
    }

    public var body: some View {
        if !cards.isEmpty {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: SparkSpacing.md, alignment: .top), count: columnCount),
                spacing: SparkSpacing.md
            ) {
                ForEach(visible) { card in
                    Button { onOpen(card) } label: { EventCard(card) }
                        .buttonStyle(.plain)
                }
                if hiddenCount > 0 {
                    Button { isExpanded = true } label: {
                        Text("+\(hiddenCount) more")
                            .font(SparkTypography.bodyStrong)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 112)
                            .background(
                                RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous)
                                    .fill(Color.sparkElevated)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows the other linked events")
                }
            }
        }
    }
}
