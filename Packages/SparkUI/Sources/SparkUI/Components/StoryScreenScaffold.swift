import SwiftUI

/// Reusable scaffold for each screen inside the Up to Speed stories flow.
/// Provides a consistent transparent container that sits over the story background.
/// When `reserveTopSpace` is true (default), adds 152 pt top padding to clear
/// the progress-bar + controls overlay at the top of the story container.
public struct StoryScreenScaffold<Content: View>: View {
    public let label: String?
    public let reserveTopSpace: Bool
    private let content: Content

    public init(
        label: String? = nil,
        reserveTopSpace: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.reserveTopSpace = reserveTopSpace
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
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, reserveTopSpace ? 152 : SparkSpacing.lg)
            .padding(.bottom, SparkSpacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .ignoresSafeArea(.container)
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
