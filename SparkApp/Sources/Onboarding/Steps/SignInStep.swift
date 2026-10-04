import SparkUI
import SwiftUI

struct SignInStep: View {
    @Environment(AppModel.self) private var model
    let proceed: () -> Void

    private struct ExplainerRow: Identifiable {
        let id: Int
        let number: String
        let title: String
        let detail: String
    }

    private let rows = [
        ExplainerRow(id: 1, number: "01", title: "Open your browser", detail: "Spark uses your account on spark.cronx.co"),
        ExplainerRow(id: 2, number: "02", title: "Sign in securely", detail: "OAuth — no password stored on your device"),
        ExplainerRow(id: 3, number: "03", title: "Return to Spark", detail: "Your data syncs automatically"),
    ]

    var body: some View {
        SparkOnboardingScaffold(icon: "sparkles", title: "Sign in") {
            VStack(spacing: SparkSpacing.md) {
                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: SparkSpacing.md) {
                        Text(row.number)
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(Color.sparkAccent)
                            .frame(width: 28, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(SparkTypography.bodyStrong)
                            Text(row.detail)
                                .font(SparkTypography.bodySmall)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
        } actions: {
            if let err = model.lastError {
                Text(err)
                    .font(SparkTypography.caption)
                    .foregroundStyle(Color.sparkError)
                    .multilineTextAlignment(.center)
            }

            PillButton("Continue with Spark", systemImage: "arrow.right.circle.fill") {
                Task {
                    guard let anchor = ASPresentationAnchorHandle.current() else { return }
                    await model.signIn(anchor: anchor)
                    // proceed() is called by OnboardingFlow via onChange(of: model.session)
                }
            }
        }
    }
}
