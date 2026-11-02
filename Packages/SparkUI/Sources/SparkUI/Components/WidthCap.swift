import SwiftUI

/// Sizes its content to fit, up to a maximum width, then lets the content
/// truncate. `.frame(maxWidth:)` is not the same thing: given a width it
/// fills it, so a pill in a VStack grew to the cap whatever its text.
public struct WidthCap: Layout {
    public let maxWidth: CGFloat

    public init(maxWidth: CGFloat) {
        self.maxWidth = maxWidth
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let ideal = content.sizeThatFits(.unspecified)
        let limit = min(maxWidth, proposal.width ?? .infinity)
        let width = min(ideal.width, limit)
        return content.sizeThatFits(ProposedViewSize(width: width, height: proposal.height))
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: bounds.origin,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )
    }
}

public extension View {
    /// Hug the content up to `maxWidth`, then truncate (see `WidthCap`).
    func sparkWidthCap(_ maxWidth: CGFloat) -> some View {
        WidthCap(maxWidth: maxWidth) { self }
    }
}
