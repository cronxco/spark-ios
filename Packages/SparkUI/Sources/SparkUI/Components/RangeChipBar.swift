import SwiftUI

/// A row of range chips (7D / 30D / 90D, 1M / 3M / …) in one glass capsule.
///
/// The selected chip is filled with the domain tint and labelled in
/// `sparkOnAccent`, which stays dark in both schemes: domain fills do not
/// change with the scheme, and white on spark-5 or the health green fails
/// contrast. Every range picker in the app uses this one control.
public struct RangeChipBar<Value: Hashable>: View {
    let options: [Value]
    let selected: Value
    let tint: Color
    let label: (Value) -> String
    let onSelect: (Value) -> Void

    public init(
        _ options: [Value],
        selected: Value,
        tint: Color,
        label: @escaping (Value) -> String,
        onSelect: @escaping (Value) -> Void
    ) {
        self.options = options
        self.selected = selected
        self.tint = tint
        self.label = label
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: SparkSpacing.xs) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selected
                Button {
                    onSelect(option)
                } label: {
                    Text(label(option))
                        .font(SparkTypography.monoSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? Color.sparkOnAccent : Color.secondary)
                        .frame(minWidth: 42)
                        .padding(.vertical, SparkSpacing.xs + 2)
                        .background {
                            if isSelected {
                                Capsule().fill(tint)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label(option)) range")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(SparkSpacing.xs)
        .sparkGlass(.capsule)
    }
}

#Preview {
    RangeChipBar(["7D", "30D", "90D"], selected: "30D", tint: .domainHealth, label: { $0 }, onSelect: { _ in })
        .padding()
        .background(Color.sparkSurface)
}
