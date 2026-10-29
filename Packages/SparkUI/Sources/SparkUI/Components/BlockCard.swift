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
    let eventID: String?

    @Environment(\.openURL) private var openURL

    /// - Parameter eventID: the event the block belongs to, for the
    ///   long-press menu's "Open event". Leave it out when the screen already
    ///   is that event.
    public init(_ block: Block, size: Size, tint: Color = .sparkAccent, eventID: String? = nil) {
        self.block = block
        self.size = size
        self.tint = tint
        self.eventID = eventID
    }

    public var body: some View {
        switch size {
        case .row: withMenu(row)
        case .compact: withMenu(compact)
        case .card: withMenu(card)
        case .full: withMenu(full)
        }
    }

    private var kind: BlockKind { block.kind }

    /// Kinds without a glyph of their own take the screen's tint.
    private var glyphTint: Color {
        kind == .genericValue || kind == .genericContent ? tint : kind.tint
    }

    private var row: some View {
        surface(radius: SparkRadii.md, padding: SparkSpacing.md) {
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
        surface(radius: SparkRadii.md, padding: SparkSpacing.md) {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                eyebrow

                if let value = block.displayValue {
                    if let fraction = value.fraction {
                        ring(value, fraction: fraction, diameter: 64)
                            .frame(maxWidth: .infinity)
                    } else {
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
        surface(radius: SparkRadii.lg, padding: SparkSpacing.lg) {
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
                    if let fraction = value.fraction {
                        ring(value, fraction: fraction, diameter: 128)
                            .frame(maxWidth: .infinity)
                    } else {
                        valueLabel(value, font: SparkTypography.bodyStrong)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var full: some View {
        if let content = nonEmpty(block.content) {
            surface(radius: SparkRadii.lg, padding: SparkSpacing.lg) {
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

    /// Generated text says so in words beside its sparkles glyph (§3.5).
    private var summaryMarker: some View {
        Text("Summary")
            .font(SparkTypography.captionStrong)
            .foregroundStyle(.secondary)
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

    /// A ratio with a known maximum (§8), as the card's hero.
    private func ring(_ value: BlockValue, fraction: Double, diameter: CGFloat) -> some View {
        ScoreRing(
            fraction: fraction,
            text: value.text,
            tint: glyphTint,
            diameter: diameter,
            threshold: excellentThreshold(for: value)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenValue(value))
    }

    /// The provider's "excellent" line, as a share of the maximum. Oura
    /// contributors are scores out of 100 with the line at 85.
    private func excellentThreshold(for value: BlockValue) -> Double? {
        guard kind == .contributor, let maximum = value.maximum, maximum > 0 else { return nil }
        return 85 / maximum
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

    /// Generated text sits on the generated surface (§3.5); everything else
    /// on the opaque content surface.
    @ViewBuilder
    private func surface<Content: View>(
        radius: CGFloat,
        padding: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if kind.isAIWritten {
            content()
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sparkGeneratedSurface(radius: radius)
        } else {
            GlassCard(radius: radius, padding: padding, content: content)
        }
    }

    /// Secondary actions live in a long-press menu with a preview of the
    /// card, on every size (§7.1). There is no visible menu button on iOS.
    @ViewBuilder
    private func withMenu(_ view: some View) -> some View {
        #if os(iOS)
        view.contextMenu {
            menu
        } preview: {
            card
                .frame(width: 320)
                .padding(SparkSpacing.sm)
        }
        #else
        view
        #endif
    }

    #if os(iOS)
    /// The same items as the web card's menu: open event, open block, open
    /// source, copy.
    @ViewBuilder
    private var menu: some View {
        if let eventID, let url = URL(string: "https://spark.cronx.co/events/\(eventID)") {
            Button("Open event", systemImage: "calendar") { openURL(url) }
        }
        if size != .full, let url = URL(string: "https://spark.cronx.co/blocks/\(block.id)") {
            Button("Open block", systemImage: "square.stack") { openURL(url) }
        }
        if let url = mediaURL {
            Button("Open source", systemImage: "safari") { openURL(url) }
        }
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
