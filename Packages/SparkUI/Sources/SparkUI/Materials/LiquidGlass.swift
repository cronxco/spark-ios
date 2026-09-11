import SwiftUI

/// Variants of the Liquid Glass surface Spark uses. Wrapped so call sites stay
/// terse and we can swap the underlying system API in one place when it
/// evolves.
public enum SparkGlassShape: Sendable {
    case capsule
    case roundedRect(CGFloat)
    case circle
}

public extension View {
    /// Apply the Liquid Glass material to a shape-constrained view.
    ///
    /// Glass is the app's default surface, which makes Reduce Transparency and
    /// Increase Contrast load-bearing rather than cosmetic: a translucent card
    /// over a gradient is exactly what those settings exist to turn off. When
    /// either is on, the surface becomes opaque with a visible edge. Falls back
    /// to a tinted material where `.glassEffect` isn't available.
    func sparkGlass(_ shape: SparkGlassShape = .capsule, tint: Color? = nil) -> some View {
        modifier(SparkGlassModifier(shape: shape, tint: tint))
    }
}

private struct SparkGlassModifier: ViewModifier {
    let shape: SparkGlassShape
    let tint: Color?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var wantsSolidSurface: Bool {
        reduceTransparency || contrast == .increased
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if wantsSolidSurface {
            switch shape {
            case .capsule:
                solid(content, in: Capsule())
            case .roundedRect(let radius):
                solid(content, in: RoundedRectangle(cornerRadius: radius))
            case .circle:
                solid(content, in: Circle())
            }
        } else {
            content.modifier(GlassSurface(shape: shape, tint: tint))
        }
    }

    /// Generic over the concrete shape so one geometry backs the fill, the tint
    /// and the border. Switching at the call site rather than erasing the type
    /// keeps `strokeBorder` available, which is an `InsettableShape` method.
    private func solid<S: InsettableShape>(_ content: Content, in shape: S) -> some View {
        content
            .background {
                // Tint sits over the opaque fill but still behind the content —
                // as an overlay it would cover the card.
                shape.fill(Color.sparkElevated)
                    .overlay(shape.fill(tint ?? .clear))
            }
            .overlay(shape.strokeBorder(Color.primary.opacity(0.25), lineWidth: 1))
    }
}

private struct GlassSurface: ViewModifier {
    let shape: SparkGlassShape
    let tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, watchOS 26.0, *) {
            switch shape {
            case .capsule:
                content.glassEffect(.regular.tint(tint ?? .clear), in: .capsule)
            case .roundedRect(let radius):
                content.glassEffect(.regular.tint(tint ?? .clear), in: .rect(cornerRadius: radius))
            case .circle:
                content.glassEffect(.regular.tint(tint ?? .clear), in: .circle)
            }
        } else {
            switch shape {
            case .capsule:
                content.background(.ultraThinMaterial, in: Capsule())
            case .roundedRect(let radius):
                content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
            case .circle:
                content.background(.ultraThinMaterial, in: Circle())
            }
        }
    }
}

/// Container wrapper for stacks of glass elements so their highlights blend
/// coherently. On older systems it's a no-op group.
@available(iOS 26.0, watchOS 26.0, *)
public struct SparkGlassStack<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    public init(spacing: CGFloat = SparkSpacing.sm, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content
        }
    }
}
