import SwiftUI

public struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?

    public init(
        systemImage: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: SparkSpacing.md) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(SparkTypography.titleStrong)
            if let message {
                Text(message)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                PillButton(actionTitle, action: action)
            }
        }
        .padding(SparkSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EmptyState(
        systemImage: "sparkles",
        title: "Nothing to show yet",
        message: "Spark will start syncing your day as soon as your first integration comes online.",
        actionTitle: "Retry",
        action: {}
    )
    .padding()
    .background(Color.sparkSurface)
}
