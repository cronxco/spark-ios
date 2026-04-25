import SparkUI
import SwiftUI

/// Placeholder modal shown when a Today CheckInCard is tapped. Day 15 of
/// Phase 2 replaces this with the full mood/tags/note flow against
/// `/api/v1/mobile/check-ins`.
struct CheckInPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: SparkSpacing.lg) {
                Spacer()
                Image(systemName: "heart.text.clipboard")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.sparkAccent)
                Text("Check-in")
                    .font(SparkTypography.hero)
                Text("The full check-in flow lands later in Phase 2 — mood scale, contextual tags, and a free-text note.")
                    .font(SparkTypography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SparkSpacing.xl)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.sparkAccent)
                    .frame(maxWidth: .infinity)
            }
            .padding(SparkSpacing.lg)
            .background(Color.sparkSurface.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
