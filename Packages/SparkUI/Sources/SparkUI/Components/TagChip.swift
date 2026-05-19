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

    @ViewBuilder
    private func typedBody(tag: EventTag, onTap: (() -> Void)?) -> some View {
        let tint = tag.tagTint
        let chip = Text(tag.name)
            .font(SparkTypography.captionStrong)
            .foregroundStyle(tint)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: 160, alignment: .leading)
            .padding(.horizontal, SparkSpacing.md - 2)
            .padding(.vertical, SparkSpacing.xs + 1)
            .sparkGlass(.capsule, tint: tint.opacity(0.15))
            .accessibilityLabel(accessibilityLabel(for: tag))
            .accessibilityAddTraits(onTap != nil ? .isButton : [])

        if let onTap {
            Button(action: onTap) { chip }
                .buttonStyle(.plain)
        } else {
            chip
        }
    }

    private func accessibilityLabel(for tag: EventTag) -> String {
        if let label = tag.tagTypeLabel {
            return "Tag \(tag.name), \(label)"
        }
        return "Tag \(tag.name)"
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

/// Minimal flow layout for chip rows. Wraps to next line when the current
/// line fills.
public struct FlowLayout: Layout {
    public let spacing: CGFloat

    public init(spacing: CGFloat = 6) { self.spacing = spacing }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var origin = CGPoint.zero
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > maxWidth, origin.x > 0 {
                origin.x = 0
                origin.y += lineHeight + spacing
                lineHeight = 0
            }
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, origin.x)
            totalHeight = origin.y + lineHeight
        }
        return CGSize(width: totalWidth, height: totalHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var origin = bounds.origin
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.origin.x {
                origin.x = bounds.origin.x
                origin.y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            _ = maxWidth
        }
    }
}
