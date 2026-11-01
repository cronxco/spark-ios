import SparkKit
import SparkUI
import SwiftUI

// The pieces every section of Explore › Money is built from, so the page
// reads as one system (docs/design-language.md sections 7, 9 and 12).

/// A section heading inside the Money page: the money glyph in its domain
/// fill, the title in the UI face, and a count in brackets ("Bills (10)").
struct MoneySectionHeader: View {
    let title: String
    let icon: SparkIcon
    var count: Int?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
            SparkGlyph(icon, size: 15, relativeTo: .headline)
                .foregroundStyle(Color.domainMoney)
            Text(count.map { "\(title) (\($0))" } ?? title)
                .font(.headline)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The card eyebrow (section 7.1): glyph, label and a trailing note.
struct MoneyEyebrow: View {
    let icon: SparkIcon
    let label: String
    var trailing: String?

    var body: some View {
        HStack(spacing: SparkSpacing.xs + 2) {
            SparkGlyph(icon, size: 12, relativeTo: .caption)
                .foregroundStyle(Color.domainMoney)
            Text(label)
                .font(SparkTypography.captionStrong)
            Spacer(minLength: SparkSpacing.sm)
            if let trailing {
                Text(trailing)
                    .font(SparkTypography.caption)
            }
        }
        .foregroundStyle(.secondary)
    }
}

/// The hero value: pounds at card size in the hero colour, pence at the
/// unit size in secondary (sections 3.6 and 4).
struct MoneyHeroValue: View {
    let whole: String
    let fraction: String
    var font: Font = SparkTypography.cardValue
    var fractionFont: Font = SparkTypography.cardUnit

    init(pence: Int, font: Font = SparkTypography.cardValue, fractionFont: Font = SparkTypography.cardUnit) {
        let parts = MoneyPlanFormat.heroParts(pence)
        self.whole = parts.whole
        self.fraction = parts.fraction
        self.font = font
        self.fractionFont = fractionFont
    }

    init(pounds: Double) {
        self.init(pence: Int((pounds * 100).rounded()))
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(whole)
                .font(font)
                .foregroundStyle(Color.sparkHero(domain: "money"))
            Text(fraction)
                .font(fractionFont)
                .foregroundStyle(.secondary)
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(whole + fraction)
    }
}

/// A status chip (section 12.9): only for a state the reader must act on.
/// The error fill with dark text, which reads at 5.9:1; white on it does not.
struct MoneyStatusChip: View {
    let text: String

    var body: some View {
        HStack(spacing: SparkSpacing.xs + 1) {
            SparkGlyph(.warning, size: 11, relativeTo: .caption)
            Text(text)
                .font(SparkTypography.captionStrong)
        }
        .foregroundStyle(Color.sparkOnAccent)
        .padding(.horizontal, SparkSpacing.md - 2)
        .frame(minHeight: 24)
        .background(Color.sparkError, in: Capsule())
    }
}

/// A `row` (section 7.2): optional glyph chip, title, metadata spaced by a
/// gap (no dividers), and a trailing value with an optional word under it
/// ("owed"), in the error colour for a debt. Nested rows sit on the page colour inside a card; rows on the
/// page sit on the content surface.
struct MoneyRow<Leading: View>: View {
    enum Ground { case nested, surface }

    let title: String
    var metadata: [String] = []
    var value: String?
    var valueCaption: String?
    var valueTint: Color?
    var ground: Ground = .nested
    var disclosure: SparkIcon?
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            leading()
            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                Text(title)
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !metadata.isEmpty {
                    MoneyMetadata(items: metadata)
                }
            }
            Spacer(minLength: SparkSpacing.sm)
            if let value {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(value)
                        .font(SparkTypography.bodyStrong)
                        .monospacedDigit()
                        .foregroundStyle(valueTint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary))
                        .lineLimit(1)
                    if let valueCaption {
                        Text(valueCaption)
                            .font(SparkTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let disclosure {
                SparkGlyph(disclosure, size: 11, relativeTo: .caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, SparkSpacing.md)
        .padding(.vertical, SparkSpacing.sm)
        .frame(minHeight: 44)
        .background {
            RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous)
                .fill(ground == .nested ? Color.sparkSurface : Color.sparkElevated)
        }
        .contentShape(RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

extension MoneyRow where Leading == EmptyView {
    init(
        title: String, metadata: [String] = [], value: String? = nil, valueCaption: String? = nil,
        valueTint: Color? = nil, ground: Ground = .nested, disclosure: SparkIcon? = nil
    ) {
        self.init(
            title: title, metadata: metadata, value: value, valueCaption: valueCaption,
            valueTint: valueTint, ground: ground, disclosure: disclosure, leading: { EmptyView() }
        )
    }
}

/// Metadata as plain text side by side, wrapping onto a new line when it
/// runs out of room (section 9). Never a row of badges, never `·`.
struct MoneyMetadata: View {
    let items: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: SparkSpacing.md) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(item).lineLimit(1)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(item).lineLimit(1)
                }
            }
        }
        .font(SparkTypography.caption)
        .foregroundStyle(.secondary)
    }
}

/// A "Show N more" control at the foot of a list.
struct MoneyShowMoreButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SparkSpacing.xs + 2) {
                SparkGlyph(.expand, size: 11, relativeTo: .subheadline)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(SparkTypography.bodyStrong)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// A bar of progress or share (section 8, Bar): the track at 15% of the
/// money fill, the value in the fill. The label and value are always text
/// beside it too.
struct MoneyBar: View {
    let fraction: Double
    let accessibilityText: String

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.domainMoney.opacity(0.15))
                Capsule()
                    .fill(Color.domainMoney)
                    .frame(width: max(0, min(1, fraction)) * proxy.size.width)
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }
}

/// The content-surface card every Money section sits on.
struct MoneyCard<Content: View>: View {
    var spacing: CGFloat = SparkSpacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(SparkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkContentSurface()
    }
}
