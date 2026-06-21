import SwiftUI

/// Reusable scaffold for each screen inside the Up to Speed stories flow.
/// Provides a consistent transparent container that sits over the story background.
/// When `reserveTopSpace` is true (default), adds 152 pt top padding to clear
/// the progress-bar + controls overlay at the top of the story container.
///
/// Pass `onReachedBottom` to be notified when the user scrolls to the end of the
/// content. A subtle "✓ Read" indicator animates in at the bottom once reached.
/// For cards whose content fits without scrolling, this fires immediately on appear.
public struct StoryScreenScaffold<Content: View>: View {
    public let label: String?
    public let reserveTopSpace: Bool
    public let onReachedBottom: (() -> Void)?
    private let content: Content

    @State private var hasReachedBottom = false

    public init(
        label: String? = nil,
        reserveTopSpace: Bool = true,
        onReachedBottom: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.reserveTopSpace = reserveTopSpace
        self.onReachedBottom = onReachedBottom
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                if let label {
                    Text(label.uppercased())
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                }
                content

                if onReachedBottom != nil {
                    readIndicator
                        .padding(.top, SparkSpacing.sm)

                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            guard !hasReachedBottom else { return }
                            hasReachedBottom = true
                            onReachedBottom?()
                        }
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, reserveTopSpace ? 152 : SparkSpacing.lg)
            .padding(.bottom, SparkSpacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .ignoresSafeArea(.container)
    }

    private var readIndicator: some View {
        HStack(spacing: SparkSpacing.xs) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
            Text("Read")
                .font(SparkTypography.caption)
        }
        .foregroundStyle(Color.sparkSuccess)
        .padding(.horizontal, SparkSpacing.md)
        .padding(.vertical, SparkSpacing.xs)
        .background(Capsule().fill(Color.sparkSuccess.opacity(0.15)))
        .opacity(hasReachedBottom ? 1 : 0)
        .scaleEffect(hasReachedBottom ? 1 : 0.8, anchor: .leading)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hasReachedBottom)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        StoryScreenScaffold(label: "Morning Digest") {
            Text("Content goes here")
                .foregroundStyle(.white)
        }
    }
}
