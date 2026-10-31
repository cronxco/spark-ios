import SwiftUI

public extension View {
    /// The surface for anything a model wrote (`docs/design-language.md`
    /// §3.5): the content surface with a diagonal spark-to-ember wash and an
    /// ember hairline, so generated text reads as Flint's voice at a glance.
    ///
    /// Opaque content, not glass. Use one per card; rows inside a generated
    /// card stay plain. Under Increase Contrast the hairline goes to full
    /// strength.
    func sparkGeneratedSurface(radius: CGFloat = SparkRadii.lg) -> some View {
        modifier(SparkGeneratedSurfaceModifier(radius: radius))
    }

    /// The full-width band of the generated surface (§3.5), for a page whose
    /// main content is generated text, such as a block of key takeaways. The
    /// same wash, no corner radius, and the ember hairline along the top and
    /// bottom only. The background runs to the screen edges; the content keeps
    /// the page's side gutter, so apply this inside the gutter's padding.
    ///
    /// Use the card (`sparkGeneratedSurface`) when the generated text sits
    /// among other cards, and never nest one in the other.
    func sparkGeneratedBand(gutter: CGFloat = SparkSpacing.lg) -> some View {
        modifier(SparkGeneratedBandModifier(gutter: gutter))
    }
}

private struct SparkGeneratedBandModifier: ViewModifier {
    let gutter: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let isDark = colorScheme == .dark
        let wash = LinearGradient(
            colors: [
                Color.spark5.opacity(isDark ? 0.10 : 0.06),
                Color.ember5.opacity(isDark ? 0.22 : 0.16),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let edge = Color.ember5.opacity(contrast == .increased ? 1 : 0.30)
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, SparkSpacing.xl)
            .background {
                Rectangle()
                    .fill(Color.sparkElevated)
                    .overlay(Rectangle().fill(wash))
                    .overlay(alignment: .top) { edge.frame(height: 1) }
                    .overlay(alignment: .bottom) { edge.frame(height: 1) }
                    // Out past the gutter to the screen edges.
                    .padding(.horizontal, -gutter)
                    .ignoresSafeArea(edges: .horizontal)
            }
    }
}

private struct SparkGeneratedSurfaceModifier: ViewModifier {
    let radius: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let isDark = colorScheme == .dark
        let wash = LinearGradient(
            colors: [
                Color.spark5.opacity(isDark ? 0.10 : 0.06),
                Color.ember5.opacity(isDark ? 0.22 : 0.16),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        content
            .background {
                shape.fill(Color.sparkElevated)
                    .overlay(shape.fill(wash))
            }
            .overlay {
                shape.strokeBorder(Color.ember5.opacity(contrast == .increased ? 1 : 0.30), lineWidth: 1)
            }
            .contentShape(shape)
    }
}
