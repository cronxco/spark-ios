import SwiftUI

/// Transient bottom bar that confirms a reversible action and offers Undo,
/// e.g. "Event deleted · Undo".
public struct UndoToast: View {
    let message: String
    let systemImage: String
    let undoTitle: String
    let isWorking: Bool
    let undo: () -> Void

    public init(
        _ message: String,
        systemImage: String = "trash",
        undoTitle: String = "Undo",
        isWorking: Bool = false,
        undo: @escaping () -> Void
    ) {
        self.message = message
        self.systemImage = systemImage
        self.undoTitle = undoTitle
        self.isWorking = isWorking
        self.undo = undo
    }

    public var body: some View {
        HStack(spacing: SparkSpacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(message)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.primary)
            Spacer(minLength: SparkSpacing.sm)
            Button(action: undo) {
                if isWorking {
                    ProgressView()
                } else {
                    Text(undoTitle)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(Color.sparkAccent)
                }
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.vertical, SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGlass(.capsule)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    VStack {
        Spacer()
        UndoToast("Event deleted") {}
            .padding()
    }
    .background(Color.sparkSurface)
}
