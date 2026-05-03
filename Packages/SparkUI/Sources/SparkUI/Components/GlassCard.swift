import SwiftUI

/// Card wrapper that applies the standard Spark glass treatment with hero or
/// regular radii. Use for Today, detail-screen sections, anywhere a grouped
/// surface needs a subtle glass shell.
public struct GlassCard<Content: View>: View {
    let radius: CGFloat
    let padding: CGFloat
    let tint: Color?
    let content: Content

    public init(
        radius: CGFloat = SparkRadii.lg,
        padding: CGFloat = SparkSpacing.lg,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.padding = padding
        self.tint = tint
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sparkGlass(.roundedRect(radius), tint: tint)
    }
}

/// Standard card header — icon + title + optional trailing meta. Pair with
/// `GlassCard` content for the Today card pattern.
public struct GlassCardHeader: View {
    public let icon: String
    public let tint: Color
    public let title: String
    public let trailing: String?

    public init(icon: String, tint: Color, title: String, trailing: String? = nil) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: SparkSpacing.sm) {
            DomainGlyph(icon: icon, tint: tint, size: 22)
            Text(title)
                .font(SparkTypography.bodyStrong)
            Spacer(minLength: SparkSpacing.sm)
            if let trailing {
                Text(trailing)
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(trailing)
            }
        }
    }
}
