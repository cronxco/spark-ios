import SparkUI
import SwiftUI

struct DoneStep: View {
    let onFinish: () -> Void

    var body: some View {
        SparkOnboardingScaffold(
            icon: "checkmark.circle.fill",
            title: "You're all set.",
            bodyText: "Spark will start building your daily intelligence as your data syncs."
        ) {
            EmptyView()
        } actions: {
            PillButton("Open Today", systemImage: "sun.max.fill") {
                let defaults = UserDefaults(suiteName: "group.co.cronx.sparkapp")
                defaults?.set(true, forKey: "onboarding.completed")
                onFinish()
            }
        }
        .navigationBarHidden(true)
    }
}
