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
        ScrollView {
            VStack(spacing: SparkSpacing.xl) {
                Spacer().frame(height: SparkSpacing.xl)

                Text("Sign in")
                    .font(SparkFonts.display(.largeTitle, weight: .bold))

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

                Spacer()

                if let err = model.lastError {
                    Text(err)
                        .font(SparkTypography.caption)
                        .foregroundStyle(Color.sparkError)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SparkSpacing.xl)
                }

                PillButton("Continue with Spark", systemImage: "arrow.right.circle.fill") {
                    Task {
                        guard let anchor = ASPresentationAnchorHandle.current() else { return }
                        await model.signIn(anchor: anchor)
                        // proceed() is called by OnboardingFlow via onChange(of: model.session)
                    }
                }
                .padding(.bottom, SparkSpacing.xxl)
            }
            .padding(.horizontal, SparkSpacing.xl)
        }
        .scrollContentBackground(.hidden)
        .background(Color.sparkSurface.ignoresSafeArea())
    }
}
