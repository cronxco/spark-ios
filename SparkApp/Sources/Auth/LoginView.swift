import SparkUI
import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: SparkSpacing.xl) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 72, weight: .regular, design: .rounded))
                .foregroundStyle(Color.sparkAccent)
            Text("Spark")
                .font(SparkTypography.displayLarge)
            Text("Your day, unified.")
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)
            Spacer()
            PillButton("Sign in with Spark", systemImage: "arrow.right.circle.fill") {
                Task {
                    guard let anchor = ASPresentationAnchorHandle.current() else { return }
                    await model.signIn(anchor: anchor)
                }
            }
            if let lastError = model.lastError {
                Text(lastError)
                    .font(SparkTypography.caption)
                    .foregroundStyle(Color.sparkNegative)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SparkSpacing.xl)
            }
            Spacer().frame(height: SparkSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sparkSurface.ignoresSafeArea())
    }
}
