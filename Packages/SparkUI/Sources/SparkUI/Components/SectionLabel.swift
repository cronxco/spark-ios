import SwiftUI

/// Small all-caps mono label used as a section heading inside detail views
/// and Today cards. Sits flush-left above the section content.
public struct SectionLabel: View {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text.uppercased())
            .font(SparkTypography.monoSmall)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}
