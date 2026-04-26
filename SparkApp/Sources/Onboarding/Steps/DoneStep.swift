import SparkUI
import SwiftUI

struct DoneStep: View {
    let onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: SparkSpacing.xl) {
                Spacer().frame(height: SparkSpacing.xxl)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(Color.sparkSuccess)

                VStack(spacing: SparkSpacing.sm) {
                    Text("You're all set.")
                        .font(SparkFonts.display(.largeTitle, weight: .bold))
                    Text("Spark will start building your daily intelligence as your data syncs.")
                        .font(SparkTypography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                PillButton("Open Today", systemImage: "sun.max.fill") {
                    let defaults = UserDefaults(suiteName: "group.co.cronx.spark")
                    defaults?.set(true, forKey: "onboarding.completed")
                    onFinish()
                }
                .padding(.bottom, SparkSpacing.xxl)
            }
            .padding(.horizontal, SparkSpacing.xl)
        }
        .scrollContentBackground(.hidden)
        .background(Color.sparkSurface.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
