import SwiftUI

public extension View {
    /// The opaque surface for content: cards and grouped rows
    /// (`docs/design-language.md` §5.3). Liquid Glass belongs to the controls
    /// layer above content, so cards sit on `sparkElevated` with no shadow.
    ///
    /// `tint` is drawn as given, between the fill and the content, so pass a
    /// faded colour (`.opacity(0.08)`). Under Reduce Transparency or Increase
    /// Contrast the card also gets a visible edge, as glass did.
    func sparkContentSurface(radius: CGFloat = SparkRadii.lg, tint: Color? = nil) -> some View {
        modifier(SparkContentSurfaceModifier(radius: radius, tint: tint))
    }
}

private struct SparkContentSurfaceModifier: ViewModifier {
    let radius: CGFloat
    let tint: Color?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                shape.fill(Color.sparkElevated)
                    .overlay(shape.fill(tint ?? .clear))
            }
            .overlay {
                if reduceTransparency || contrast == .increased {
                    shape.strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
                }
            }
            .contentShape(shape)
    }
}
