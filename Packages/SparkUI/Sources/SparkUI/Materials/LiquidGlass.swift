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
    /// Apply the Liquid Glass material to a shape-constrained view. Falls back
    /// to a tinted material on platforms where `.glassEffect` isn't available.
    @ViewBuilder
    func sparkGlass(_ shape: SparkGlassShape = .capsule, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, watchOS 26.0, *) {
            switch shape {
            case .capsule:
                glassEffect(.regular.tint(tint ?? .clear), in: .capsule)
            case .roundedRect(let radius):
                glassEffect(.regular.tint(tint ?? .clear), in: .rect(cornerRadius: radius))
            case .circle:
                glassEffect(.regular.tint(tint ?? .clear), in: .circle)
            }
        } else {
            switch shape {
            case .capsule:
                background(.ultraThinMaterial, in: Capsule())
            case .roundedRect(let radius):
                background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
            case .circle:
                background(.ultraThinMaterial, in: Circle())
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
