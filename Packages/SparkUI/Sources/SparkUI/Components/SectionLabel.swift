import SwiftUI

/// Section label that can sit above content or beside a Day filter control.
///
/// Renders the text as given. Spark is sentence case throughout, labels
/// included, so pass "Recent events", never "RECENT EVENTS".
public struct SectionLabel: View {
    public enum Style {
        case compact
        case dayHeading
    }

    public let text: String
    public let style: Style

    public init(_ text: String, style: Style = .compact) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(style == .dayHeading ? SparkTypography.sectionHeading : SparkTypography.captionStrong)
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }
}
