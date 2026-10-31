import SwiftUI

/// A Font Awesome glyph from the manifest (`SparkIcon`), drawn in the bundled
/// font so it scales with Dynamic Type beside its text. Takes the foreground
/// style it is given: a domain glyph its domain fill, an interface glyph
/// stays neutral (`docs/design-language.md` section 6).
///
/// Decorative by default, because a label sits beside every glyph. Give it an
/// `accessibilityLabel` where it stands alone.
public struct SparkGlyph: View {
    let icon: SparkIcon
    let size: CGFloat
    let style: Font.TextStyle

    public init(_ icon: SparkIcon, size: CGFloat = 16, relativeTo style: Font.TextStyle = .body) {
        self.icon = icon
        self.size = size
        self.style = style
    }

    public var body: some View {
        Text(icon.glyph)
            .font(SparkFonts.icon(size: size, relativeTo: style))
            .accessibilityHidden(true)
    }
}

public extension SparkIcon {
    /// The domain's own glyph (section 3.2), or `link` for a domain the
    /// design language does not name.
    static func domain(_ domain: String?) -> SparkIcon {
        switch (domain ?? "").lowercased() {
        case "health": .health
        case "activity": .activity
        case "money": .money
        case "media": .media
        case "knowledge": .knowledge
        case "online": .online
        case "anomaly": .anomaly
        default: .link
        }
    }
}
