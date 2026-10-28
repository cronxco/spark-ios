import SparkKit
import SwiftUI

/// The one view that draws a block, wherever it appears.
///
/// Screens decide which blocks to show and in what order; `BlockCard`
/// decides how each one looks, from its `BlockKind` and the size it's given.
/// Layouts for a particular kind belong here, so the event screen, Knowledge
/// and the block screen pick them up together. The sizes are the ones in
/// `docs/design-language.md` §7.2.
public struct BlockCard: View {
    public enum Size: Sendable {
        /// A text block in a list: its title and the start of its content,
        /// so you can tell which one to open.
        case row
        /// A block with a value, in a grid: label, value and unit.
        case compact
        /// A block read in place, inside an event or Knowledge item: its
        /// title over its full content.
        case card
        /// The block's own screen, below the hero: its full content.
        case full
    }

    let block: Block
    let size: Size
    let tint: Color

    public init(_ block: Block, size: Size, tint: Color = .sparkAccent) {
        self.block = block
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        switch size {
        case .row: row
        case .compact: compact
        case .card: card
        case .full: full
        }
    }

    private var row: some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            HStack(alignment: .center, spacing: SparkSpacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(heading)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let preview = block.preview {
                        Text(preview)
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var compact: some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                Text(heading)
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(block.value?.sparkPlainTextFromHTMLFragment ?? "")
                    .font(SparkFonts.display(.title2, weight: .bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let unit = block.unit, !unit.isEmpty {
                    Text(unit)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var card: some View {
        GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.lg) {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel(heading, style: .dayHeading)

                if let content = nonEmpty(block.content) {
                    SparkLongFormContentView(text: content, paragraphFont: SparkTypography.body)
                }

                if let value = valueText {
                    Text(value)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var full: some View {
        if let content = nonEmpty(block.content) {
            GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.lg) {
                SparkLongFormContentView(text: content, paragraphFont: SparkTypography.longFormBody)
            }
        }
    }

    /// The block's title, or its type in words when the title is blank.
    private var heading: String {
        nonEmpty(block.title) ?? block.blockType.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var valueText: String? {
        guard let value = nonEmpty(block.value?.sparkPlainTextFromHTMLFragment) else { return nil }
        return [value, nonEmpty(block.unit)].compactMap { $0 }.joined(separator: " ")
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
