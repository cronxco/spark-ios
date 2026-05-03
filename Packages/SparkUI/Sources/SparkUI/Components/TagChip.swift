import SwiftUI

/// Small `#tag` style chip used in detail views and the tag editor. Ghost
/// variant carries dashed outline for "add" affordances.
public struct TagChip: View {
    public let text: String
    public let isGhost: Bool

    public init(_ text: String, isGhost: Bool = false) {
        self.text = text
        self.isGhost = isGhost
    }

    public var body: some View {
        Text(isGhost ? text : "#\(text)")
            .font(SparkTypography.monoSmall)
            .foregroundStyle(.primary)
            .padding(.horizontal, SparkSpacing.md - 2)
            .padding(.vertical, SparkSpacing.xs + 1)
            .background(background)
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

    @ViewBuilder
    private var background: some View {
        if isGhost {
            Color.clear
        } else {
            Color.primary.opacity(0.06)
        }
    }
}

/// A flowing chip cluster that wraps tags onto multiple lines.
public struct TagChipRow: View {
    public let tags: [String]
    public let allowAdd: Bool
    public let onAdd: (() -> Void)?

    public init(_ tags: [String], allowAdd: Bool = false, onAdd: (() -> Void)? = nil) {
        self.tags = tags
        self.allowAdd = allowAdd
        self.onAdd = onAdd
    }

    public var body: some View {
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
}

/// Minimal flow layout for chip rows. Wraps to next line when the current
/// line fills. Avoids dragging in a heavier external layout helper.
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
