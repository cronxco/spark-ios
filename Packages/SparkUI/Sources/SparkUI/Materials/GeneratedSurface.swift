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
