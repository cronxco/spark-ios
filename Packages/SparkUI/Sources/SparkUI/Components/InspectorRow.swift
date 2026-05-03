import SwiftUI

/// Key/value row for the Inspector layout — small mono key on the left,
/// regular value on the right with an optional mono treatment for
/// timestamps/IDs. Stack rows directly without padding wrappers; the row
/// draws its own bottom hairline so a series reads as a clean ledger.
public struct InspectorRow<Value: View>: View {
    public let key: String
    public let isMono: Bool
    public let value: Value

    public init(_ key: String, isMono: Bool = false, @ViewBuilder value: () -> Value) {
        self.key = key
        self.isMono = isMono
        self.value = value()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.md) {
            Text(key.uppercased())
                .font(SparkTypography.monoSmall)
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)
                .accessibilityHidden(true)

            value
                .font(isMono ? SparkTypography.mono : SparkTypography.bodySmall)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.vertical, SparkSpacing.sm + 3)
        .padding(.horizontal, SparkSpacing.md)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(key)
    }
}

public extension InspectorRow where Value == Text {
    /// Convenience for plain-text values.
    init(_ key: String, _ value: String, isMono: Bool = false) {
        self.init(key, isMono: isMono) { Text(value) }
    }
}
