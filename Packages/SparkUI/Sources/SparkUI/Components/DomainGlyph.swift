import SwiftUI

/// Small tinted SF symbol in a muted square — used as the leading glyph on
/// domain cards, list rows, and headers. Background is a faint material so
/// the glyph reads at every size class without colour overload.
public struct DomainGlyph: View {
    public let icon: String
    public let tint: Color
    public let size: CGFloat

    public init(icon: String, tint: Color, size: CGFloat = 30) {
        self.icon = icon
        self.tint = tint
        self.size = size
    }

    public var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.5, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(.thinMaterial, in: .rect(cornerRadius: SparkRadii.sm))
            .accessibilityHidden(true)
    }
}
