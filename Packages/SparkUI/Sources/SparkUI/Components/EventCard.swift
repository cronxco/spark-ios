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
        let value = Text(card.heroValue)
            .font(SparkFonts.display(.title2, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

        if let maximum = kind.ringMaximum, let live = card.liveValue {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: SparkSpacing.sm) {
                    ring(live, maximum: maximum)
                    value
                }
                value
            }
        } else {
            value
        }
    }

    private func ring(_ live: Double, maximum: Double) -> some View {
        Gauge(value: min(max(live, 0), maximum), in: 0 ... maximum) { EmptyView() }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(fill)
            .scaleEffect(0.55)
            .frame(width: 32, height: 32)
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

        let systemImage = switch (context.withinUsualRange, context.direction) {
        case (true, _), (_, .flat): "arrow.right"
        case (_, .up): "arrow.up"
        case (_, .down): "arrow.down"
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

    /// One VoiceOver element: "Sleep score, 66, 12 below your 30d trend".
    /// Scores carry "out of 100" here and nowhere else (§9).
    private var accessibilityText: String {
        var parts = [card.label]
        if let maximum = kind.ringMaximum, card.liveValue != nil {
            parts.append("\(card.heroValue) out of \(Int(maximum))")
        } else {
            parts.append(card.heroValue)
        }
        if let line = contextLine { parts.append(line.text) }
        return parts.joined(separator: ", ")
    }
}

/// Up to three compact event cards under a paragraph, in the order the prose
/// mentions them. Past three, the third slot reads "+N more" and reveals the
/// rest (design language §7.3). Tapping a card opens its event.
public struct EventCardRow: View {
    let cards: [LinkedEventCard]
    let onOpen: (LinkedEventCard) -> Void

    @State private var isExpanded = false

    public init(_ cards: [LinkedEventCard], onOpen: @escaping (LinkedEventCard) -> Void) {
        self.cards = cards
        self.onOpen = onOpen
    }

    private var visible: [LinkedEventCard] {
        isExpanded || cards.count <= 3 ? cards : Array(cards.prefix(2))
    }

    private var hiddenCount: Int { cards.count - visible.count }

    public var body: some View {
        if !cards.isEmpty {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: SparkSpacing.md, alignment: .top), count: min(3, max(2, cards.count))),
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
