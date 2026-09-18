import SwiftUI

/// Small mono label used as a section heading inside detail views and Today
/// cards. Sits flush-left above the section content.
///
/// Renders the text as given. Spark is sentence case throughout, labels
/// included, so pass "Recent events", never "RECENT EVENTS".
public struct SectionLabel: View {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(SparkTypography.monoSmall)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}
