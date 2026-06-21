import SwiftUI

/// Horizontal row of emoji buttons for a 1–N rating, used in check-in forms.
/// `selected` is 1-indexed (matches the 1…emojis.count range), or nil if unset.
public struct EmojiRatingRow: View {
    @Binding public var selected: Int?
    public let emojis: [String]
    public let labels: [String]

    public init(selected: Binding<Int?>, emojis: [String], labels: [String]) {
        self._selected = selected
        self.emojis = emojis
        self.labels = labels
    }

    public var body: some View {
        HStack(spacing: SparkSpacing.lg) {
            ForEach(Array(emojis.enumerated()), id: \.offset) { index, emoji in
                let value = index + 1
                Button {
                    selected = selected == value ? nil : value
                } label: {
                    Text(emoji)
                        .font(.system(size: 28))
                        .opacity(selected == value ? 1 : 0.35)
                        .scaleEffect(selected == value ? 1.15 : 1.0)
                        .animation(.spring(response: 0.2), value: selected)
                        .padding(SparkSpacing.xs)
                        .background(
                            selected == value
                                ? Color.sparkAccent.opacity(0.12)
                                : Color.clear
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(labels[index]), \(value) of \(emojis.count)")
                .accessibilityAddTraits(selected == value ? .isSelected : [])
            }
        }
    }
}
