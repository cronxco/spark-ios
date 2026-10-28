import SparkKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

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
        case .row: withMenu(row)
        case .compact: withMenu(compact)
        case .card: withMenu(card)
        case .full: full
        }
    }

    private var kind: BlockKind { block.kind }

    /// Kinds without a glyph of their own take the screen's tint.
    private var glyphTint: Color {
        kind == .genericValue || kind == .genericContent ? tint : kind.tint
    }

    private var row: some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            HStack(alignment: .center, spacing: SparkSpacing.md) {
                if let url = mediaURL {
                    thumbnail(url)
                } else {
                    glyphChip(size: 32)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(heading)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if kind.isAIWritten {
                        summaryMarker
                    }

                    if let preview = block.preview {
                        Text(preview)
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                if let value = block.displayValue {
                    valueLabel(value, font: SparkTypography.bodyStrong)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
        }
        .accessibilityElement(children: .combine)
    }

    private var compact: some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                eyebrow

                if let value = block.displayValue {
                    HStack(alignment: .center, spacing: SparkSpacing.sm) {
                        if let fraction = value.fraction {
                            ring(fraction)
                        }
                        valueLabel(value, font: SparkFonts.display(.title2, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                } else {
                    Text("—")
                        .font(SparkFonts.display(.title2, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var card: some View {
        GlassCard(
            radius: SparkRadii.lg,
            padding: SparkSpacing.lg,
            tint: kind.isAIWritten ? Color.sparkAccent.opacity(0.06) : nil
        ) {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
                    Image(systemName: kind.systemImage)
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(glyphTint)
                        .accessibilityHidden(true)
                    SectionLabel(heading, style: .dayHeading)
                    Spacer(minLength: SparkSpacing.sm)
                    if kind.isAIWritten {
                        summaryMarker
                    }
                }

                if let url = mediaURL {
                    artwork(url)
                }

                if let content = nonEmpty(block.content) {
                    SparkLongFormContentView(text: content, paragraphFont: SparkTypography.body)
                }

                if let value = block.displayValue {
                    valueLabel(value, font: SparkTypography.bodyStrong)
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

    // MARK: Parts

    /// Glyph and label, the top line of a compact card (§7.1).
    private var eyebrow: some View {
        HStack(spacing: SparkSpacing.xs) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(glyphTint)
                .accessibilityHidden(true)
            Text(kind.isAIWritten ? "Summary · \(heading)" : heading)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(SparkTypography.captionStrong)
    }

    /// Generated text says so in words as well as with the glyph (§3.4).
    private var summaryMarker: some View {
        Label("Summary", systemImage: "sparkles")
            .font(SparkTypography.captionStrong)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }

    /// The hero value with its unit smaller beside it, baseline-aligned (§3.3).
    private func valueLabel(_ value: BlockValue, font: Font) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value.text)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(.primary)
            if let unit = value.unit {
                Text(unit)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenValue(value))
    }

    private func spokenValue(_ value: BlockValue) -> String {
        if let maximum = value.maximum, value.unit != "%" {
            return "\(value.text) out of \(maximum.formatted())"
        }
        return [value.text, value.unit].compactMap { $0 }.joined(separator: " ")
    }

    /// A ratio with a known maximum (§8): the track at 15%, the stroke in the
    /// kind's fill.
    private func ring(_ fraction: Double) -> some View {
        Gauge(value: fraction) {
            EmptyView()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(glyphTint)
        .scaleEffect(0.6)
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }

    private func glyphChip(size: CGFloat) -> some View {
        Image(systemName: kind.systemImage)
            .font(.system(size: size * 0.5, weight: .medium))
            .foregroundStyle(glyphTint)
            .frame(width: size, height: size)
            .background(glyphTint.opacity(0.12), in: RoundedRectangle(cornerRadius: SparkRadii.sm, style: .continuous))
            .accessibilityHidden(true)
    }

    private func thumbnail(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                glyphChip(size: 40)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: SparkRadii.sm, style: .continuous))
        .accessibilityHidden(true)
    }

    /// Image-led body (§8): the aspect ratio comes from the kind, and the
    /// placeholder is the kind's glyph on a 12% tint. Artwork is never tinted.
    private func artwork(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    glyphTint.opacity(0.12)
                    Image(systemName: kind.systemImage)
                        .font(.title2)
                        .foregroundStyle(glyphTint)
                }
            }
        }
        .aspectRatio(artworkAspectRatio, contentMode: .fit)
        .frame(maxWidth: artworkMaxWidth)
        .clipShape(RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous))
        .accessibilityLabel(heading)
    }

    private var artworkAspectRatio: CGFloat {
        switch kind {
        case .albumArt: 1
        case .bookCover, .book: 2.0 / 3.0
        default: 16.0 / 9.0
        }
    }

    /// Square and portrait artwork stays artwork-sized; photos fill the width.
    private var artworkMaxWidth: CGFloat {
        switch kind {
        case .albumArt, .bookCover, .book: 180
        default: .infinity
        }
    }

    private var mediaURL: URL? {
        guard let raw = nonEmpty(block.mediaUrl) else { return nil }
        return URL(string: raw)
    }

    /// Secondary actions live in a long-press menu, not on the card (§7.1).
    @ViewBuilder
    private func withMenu(_ card: some View) -> some View {
        #if os(iOS)
        card.contextMenu { menu }
        #else
        card
        #endif
    }

    #if os(iOS)
    @ViewBuilder
    private var menu: some View {
        if let value = block.displayValue {
            Button("Copy value", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = [value.text, value.unit].compactMap { $0 }.joined(separator: " ")
            }
        }
        if let text = nonEmpty(block.content?.sparkPlainTextFromHTMLFragment) {
            Button("Copy text", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = text
            }
        }
        if let url = mediaURL {
            ShareLink(item: url)
        }
    }
    #endif

    /// The block's title, or its type in words when the title is blank.
    private var heading: String {
        nonEmpty(block.title) ?? block.blockType.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
