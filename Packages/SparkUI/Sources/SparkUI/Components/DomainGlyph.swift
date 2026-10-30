import SwiftUI

/// The glyph chip (`docs/design-language.md` section 6): the glyph in its
/// domain fill on a 12% tint of the same fill, in a rounded square. 30pt on a
/// row, 42pt on a detail hero.
///
/// It is content, so it is opaque rather than glass. `backing` puts a solid
/// colour under the tint, for a chip that sits over a line, such as a node
/// on the timeline spine.
public struct DomainGlyph: View {
    private enum Glyph {
        case symbol(String)
        case icon(SparkIcon)
    }

    private let glyph: Glyph
    public let tint: Color
    public let size: CGFloat
    private let backing: Color?

    /// A Font Awesome glyph from the manifest. Prefer this.
    public init(_ icon: SparkIcon, tint: Color, size: CGFloat = 30, backing: Color? = nil) {
        self.glyph = .icon(icon)
        self.tint = tint
        self.size = size
        self.backing = backing
    }

    /// An SF Symbol, for screens not yet moved onto the manifest.
    public init(icon: String, tint: Color, size: CGFloat = 30) {
        self.glyph = .symbol(icon)
        self.tint = tint
        self.size = size
        self.backing = nil
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: SparkRadii.sm, style: .continuous)
        Group {
            switch glyph {
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: size * 0.5, weight: .medium))
            case .icon(let icon):
                Text(icon.glyph)
                    // Fixed, because the chip's frame is fixed too.
                    .font(.custom(SparkFonts.iconPostScriptName, fixedSize: size * 0.47))
            }
        }
        .foregroundStyle(tint)
        .frame(width: size, height: size)
        .background {
            shape.fill(backing ?? .clear)
                .overlay(shape.fill(tint.opacity(0.12)))
        }
        .accessibilityHidden(true)
    }
}
