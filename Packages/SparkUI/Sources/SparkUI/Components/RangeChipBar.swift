import SwiftUI

/// A row of tappable range chips (e.g. D / W / M / Y) using native Liquid
/// Glass. The active chip is tinted with the given domain colour; inactive
/// chips use untinted glass. All chips are grouped in a GlassEffectContainer
/// so their highlights blend correctly.
public struct RangeChipBar: View {
    public let items: [String]
    @Binding public var selected: String
    public let tint: Color
    public let accessibilityLabel: (String) -> String

    public init(
        items: [String],
        selected: Binding<String>,
        tint: Color = .accentColor,
        accessibilityLabel: @escaping (String) -> String = { "\($0) range" }
    ) {
        self.items = items
        self._selected = selected
        self.tint = tint
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        chipRow
    }

    @ViewBuilder
    private var chipRow: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 4) {
                chips
            }
        } else {
            chips
        }
    }

    private var chips: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                let isActive = item == selected
                Button {
                    selected = item
                } label: {
                    Text(item)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(isActive ? Color.primary : Color.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .sparkGlass(.capsule, tint: isActive ? tint : nil)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(item))
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
    }
}
