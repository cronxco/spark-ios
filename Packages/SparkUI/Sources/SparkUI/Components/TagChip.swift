import SparkKit
import SwiftUI

// MARK: - EventTag display helpers

public struct SparkTagPresentation {
    public enum Kind: Sendable, Equatable {
        case person
        case place
        case topic
        case unknownTyped
        case untyped
    }

    public let kind: Kind
    public let label: String?
    public let tint: Color

    public static func resolve(name: String, type: String?) -> SparkTagPresentation {
        guard let rawType = type?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawType.isEmpty
        else {
            return SparkTagPresentation(kind: .untyped, label: nil, tint: Color.primary.opacity(0.55))
        }

        let normalized = rawType.lowercased()
        let tokens = Set(Self.tokens(from: normalized))

        if Self.matches(tokens: tokens, normalized: normalized, terms: personTerms) {
            return SparkTagPresentation(kind: .person, label: "Person", tint: .sparkTagPerson)
        }
        if Self.matches(tokens: tokens, normalized: normalized, terms: topicTerms) {
            return SparkTagPresentation(kind: .topic, label: Self.humanized(rawType), tint: .sparkTagTopic)
        }
        if Self.matches(tokens: tokens, normalized: normalized, terms: placeTerms) {
            return SparkTagPresentation(kind: .place, label: "Place", tint: .sparkTagPlace)
        }

        return SparkTagPresentation(
            kind: .unknownTyped,
            label: Self.humanized(rawType),
            tint: Self.stableTint(seed: "\(normalized):\(name.lowercased())")
        )
    }

    private static let personTerms = [
        "person", "people", "user", "contact", "human", "profile", "friend", "colleague",
    ]

    private static let placeTerms = [
        "place", "location", "venue", "merchant", "store", "restaurant", "address", "geo",
    ]

    private static let topicTerms = [
        "topic", "category", "domain", "interest", "theme", "label",
    ]

    private static func matches(tokens: Set<String>, normalized: String, terms: [String]) -> Bool {
        terms.contains { term in
            tokens.contains(term) || normalized.contains(term)
        }
    }

    private static func tokens(from value: String) -> [String] {
        let separated = value.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(separated).split(separator: " ").map(String.init)
    }

    private static func humanized(_ value: String) -> String {
        let words = tokens(from: value)
        guard !words.isEmpty else { return value.capitalized }
        return words
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func stableTint(seed: String) -> Color {
        let palette: [Color] = [.sparkAccent, .sparkOcean, .sparkWarning, .sparkSuccess, .sparkTagPerson, .sparkTagTopic]
        let checksum = seed.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0x7fffffff
        }
        return palette[checksum % palette.count]
    }
}

public extension EventTag {
    var tagPresentation: SparkTagPresentation {
        SparkTagPresentation.resolve(name: name, type: type)
    }

    var tagTint: Color {
        tagPresentation.tint
    }

    var tagTypeLabel: String? {
        tagPresentation.label
    }

    /// The name as people read it. Integrations sometimes tag with a raw
    /// code ("uk_retail_pot"); those read as words ("UK retail pot"). Any
    /// name with capitals or spaces is the source's own and stays as it is.
    /// Routes and lookups keep using `name`.
    var displayName: String {
        SparkTagPresentation.displayName(for: name)
    }
}

public extension SparkTagPresentation {
    private static let acronyms: Set<String> = ["uk", "us", "eu", "gb", "atm", "pos", "id", "tv", "dj"]

    static func displayName(for name: String) -> String {
        guard name.contains("_"),
              name == name.lowercased(),
              !name.contains(" ")
        else { return name }

        let words = name.split(separator: "_").map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return name }
        return words.enumerated().map { index, word in
            if acronyms.contains(word) { return word.uppercased() }
            return index == 0 ? word.prefix(1).uppercased() + word.dropFirst() : word
        }
        .joined(separator: " ")
    }
}

// MARK: - PeekableTagChip

/// A tag that opens its peek card on a tap (`docs/design-language.md`
/// section 7.5): the type as the eyebrow, the name, and a button to the
/// tag's items. Without `onOpen`, the card says there is nothing to open.
public struct PeekableTagChip: View {
    public let tag: EventTag
    public let facts: [PeekCard.Fact]
    public let onOpen: (() -> Void)?

    @State private var isPeeking = false

    public init(_ tag: EventTag, facts: [PeekCard.Fact] = [], onOpen: (() -> Void)?) {
        self.tag = tag
        self.facts = facts
        self.onOpen = onOpen
    }

    private var openFromPeek: (() -> Void)? {
        guard let onOpen else { return nil }
        return {
            isPeeking = false
            onOpen()
        }
    }

    public var body: some View {
        TagChip(tag) { isPeeking.toggle() }
            .sparkPeek(isPresented: $isPeeking) {
                TagPeekCard(tag: tag, facts: facts, onOpen: openFromPeek)
            }
    }
}

/// A tag's peek card, built from the name and type it carries.
public struct TagPeekCard: View {
    public let tag: EventTag
    public let facts: [PeekCard.Fact]
    public let onOpen: (() -> Void)?

    /// - Parameter facts: a few lines under the title, such as how many
    ///   events and objects carry the tag.
    public init(tag: EventTag, facts: [PeekCard.Fact] = [], onOpen: (() -> Void)?) {
        self.tag = tag
        self.facts = facts
        self.onOpen = onOpen
    }

    /// The type in sentence case ("Music album tag"), as section 4 asks.
    private var eyebrow: String {
        guard let label = tag.tagTypeLabel else { return "Tag" }
        let text = "\(label) tag".lowercased()
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    public var body: some View {
        PeekCard(
            icon: TagChip.icon(forType: tag.type),
            tint: SparkRole.forTagType(tag.type).fill,
            eyebrow: eyebrow,
            title: tag.displayName,
            facts: facts,
            action: onOpen.map { PeekCard.Action("View tagged items", perform: $0) },
            noDestination: "This tag has no page to open."
        )
    }
}

// MARK: - TagChip

/// Tag chip supporting both typed `EventTag` (colour-coded, no `#`) and a
/// legacy plain-string variant (keeps `#` prefix and ghost affordance) for
/// non-tag surfaces like `ApiTokensView`.
public struct TagChip: View {
    private enum Content {
        case typed(EventTag, onTap: (() -> Void)?)
        case plain(String, isGhost: Bool)
    }

    private let content: Content

    /// Colour-coded chip for a typed `EventTag`. Omit `onTap` for display-only.
    public init(_ tag: EventTag, onTap: (() -> Void)? = nil) {
        self.content = .typed(tag, onTap: onTap)
    }

    /// Legacy plain-string chip. Preserves `#` prefix and ghost variant.
    public init(_ text: String, isGhost: Bool = false) {
        self.content = .plain(text, isGhost: isGhost)
    }

    public var body: some View {
        switch content {
        case .typed(let tag, let onTap):
            typedBody(tag: tag, onTap: onTap)
        case .plain(let text, let isGhost):
            legacyBody(text: text, isGhost: isGhost)
        }
    }

    /// An outline pill (`docs/design-language.md` section 7.5): border and
    /// text in the tag type's role colour, no fill, with the type's glyph at
    /// 70%. Text takes the role's ink so it clears 4.5:1 in light mode.
    @ViewBuilder
    private func typedBody(tag: EventTag, onTap: (() -> Void)?) -> some View {
        let role = SparkRole.forTagType(tag.type)
        let chip = HStack(spacing: SparkSpacing.xs) {
            SparkGlyph(Self.icon(forType: tag.type), size: 10, relativeTo: .caption)
                .opacity(0.7)
            Text(tag.displayName)
                .font(SparkTypography.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(role.ink)
        .sparkWidthCap(220)
        .padding(.horizontal, SparkSpacing.sm)
        .padding(.vertical, SparkSpacing.xxs)
        .overlay {
            Capsule().strokeBorder(role.fill, lineWidth: 1)
        }
        .contentShape(.capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: tag))
        .accessibilityAddTraits(onTap != nil ? .isButton : [])

        if let onTap {
            Button(action: onTap) { chip }
                .buttonStyle(.plain)
        } else {
            chip
        }
    }

    static func icon(forType type: String?) -> SparkIcon {
        let type = (type ?? "").lowercased()
        if type.contains("artist") { return .artist }
        if type.contains("album") { return .album }
        if type.contains("person") { return .person }
        return .tag
    }

    private func accessibilityLabel(for tag: EventTag) -> String {
        if let label = tag.tagTypeLabel {
            return "Tag \(tag.displayName), \(label)"
        }
        return "Tag \(tag.displayName)"
    }

    private func legacyBody(text: String, isGhost: Bool) -> some View {
        Text(isGhost ? text : "#\(text)")
            .font(SparkTypography.monoSmall)
            .foregroundStyle(.primary)
            .padding(.horizontal, SparkSpacing.md - 2)
            .padding(.vertical, SparkSpacing.xs + 1)
            .background(isGhost ? Color.clear : Color.primary.opacity(0.06))
            .clipShape(.capsule)
            .overlay {
                if isGhost {
                    Capsule()
                        .strokeBorder(.secondary.opacity(0.4),
                                      style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                }
            }
            .accessibilityLabel(isGhost ? "Add tag" : "Tag \(text)")
    }
}

// MARK: - TagChipRow

/// A flowing chip cluster that wraps tags onto multiple lines.
///
/// Two overloads:
/// - `[EventTag]` — colour-coded chips with optional tap and overflow truncation.
/// - `[String]` — legacy plain chips for non-tag surfaces (unchanged behaviour).
public struct TagChipRow: View {
    private enum Mode {
        case strings([String], allowAdd: Bool, onAdd: (() -> Void)?)
        case tags([EventTag], maxVisible: Int, onTap: ((EventTag) -> Void)?)
    }

    private let mode: Mode
    @State private var expanded = false

    public init(_ tags: [String], allowAdd: Bool = false, onAdd: (() -> Void)? = nil) {
        self.mode = .strings(tags, allowAdd: allowAdd, onAdd: onAdd)
    }

    public init(_ tags: [EventTag], maxVisible: Int = 6, onTap: ((EventTag) -> Void)? = nil) {
        self.mode = .tags(tags, maxVisible: maxVisible, onTap: onTap)
    }

    public var body: some View {
        switch mode {
        case .strings(let tags, let allowAdd, let onAdd):
            stringBody(tags: tags, allowAdd: allowAdd, onAdd: onAdd)
        case .tags(let tags, let maxVisible, let onTap):
            tagBody(tags: tags, maxVisible: maxVisible, onTap: onTap)
        }
    }

    private func stringBody(tags: [String], allowAdd: Bool, onAdd: (() -> Void)?) -> some View {
        FlowLayout(spacing: SparkSpacing.xs + 2) {
            ForEach(tags, id: \.self) { TagChip($0) }
            if allowAdd {
                Button(action: { onAdd?() }) {
                    TagChip("+", isGhost: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add tag")
            }
        }
    }

    private func tagBody(tags: [EventTag], maxVisible: Int, onTap: ((EventTag) -> Void)?) -> some View {
        let visible = expanded ? tags : Array(tags.prefix(maxVisible))
        let overflow = tags.count - maxVisible

        return FlowLayout(spacing: SparkSpacing.xs + 2) {
            ForEach(visible) { tag in
                TagChip(tag, onTap: onTap.map { handler in { handler(tag) } })
            }
            if !expanded && overflow > 0 {
                Button {
                    expanded = true
                } label: {
                    Text("+\(overflow) more")
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, SparkSpacing.md - 2)
                        .padding(.vertical, SparkSpacing.xs + 1)
                        .sparkGlass(.capsule, tint: Color.primary.opacity(0.06))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show \(overflow) more tags")
            }
        }
    }
}

// MARK: - FlowLayout

/// Minimal flow layout for chip rows. Wraps to the next line when the current
/// line fills, and centres each item on its line, so a run of text sits level
/// with the pills beside it instead of riding at their top edge.
public struct FlowLayout: Layout {
    public let spacing: CGFloat
    public let lineSpacing: CGFloat

    /// - Parameters:
    ///   - spacing: the gap between items on a line.
    ///   - lineSpacing: the gap between wrapped lines; the same as `spacing`
    ///     unless given.
    public init(spacing: CGFloat = 6, lineSpacing: CGFloat? = nil) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing ?? spacing
    }

    private struct Line {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrangeLines(for subviews: Subviews, maxWidth: CGFloat) -> [Line] {
        var lines: [Line] = [Line()]
        for (index, subview) in zip(subviews.indices, subviews) {
            let size = Self.size(of: subview, lineWidth: maxWidth)
            let gap = lines[lines.count - 1].items.isEmpty ? 0 : spacing
            if lines[lines.count - 1].width + gap + size.width > maxWidth, !lines[lines.count - 1].items.isEmpty {
                lines.append(Line())
            }
            var line = lines[lines.count - 1]
            line.width += (line.items.isEmpty ? 0 : spacing) + size.width
            line.height = max(line.height, size.height)
            line.items.append((index, size))
            lines[lines.count - 1] = line
        }
        return lines.filter { !$0.items.isEmpty }
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = arrangeLines(for: subviews, maxWidth: proposal.width ?? .infinity)
        // Never wider than offered: a stack takes its widest child's width,
        // so an overrun here pushed every other timeline row off the spine.
        let width = min(lines.map(\.width).max() ?? 0, proposal.width ?? .infinity)
        let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(lines.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in arrangeLines(for: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for item in line.items {
                let origin = CGPoint(x: x, y: y + (line.height - item.size.height) / 2)
                subviews[item.index].place(at: origin, proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    /// Each item gets its ideal size. Only one wider than a line is offered
    /// the line's width, so a long text wraps inside it; offering every item
    /// the line would stretch anything with a flexible frame to fill it.
    private static func size(of subview: LayoutSubview, lineWidth: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        guard lineWidth.isFinite, ideal.width > lineWidth else { return ideal }
        return subview.sizeThatFits(ProposedViewSize(width: lineWidth, height: nil))
    }
}
