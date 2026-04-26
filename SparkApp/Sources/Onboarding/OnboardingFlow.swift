import SparkUI
import SwiftUI

/// Root of the onboarding flow. Drives a NavigationStack through all steps.
/// Persists the last-completed step so the user can resume after interruption.
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    @State private var path: [Step] = []
    @Binding var isComplete: Bool

    enum Step: String, Hashable, CaseIterable {
        case signIn
        case healthKitEssentials
        case healthKitActivity
        case healthKitAdvanced
        case notifications
        case location
        case done
    }

    var body: some View {
        NavigationStack(path: $path) {
            HeroStep { push(.signIn) }
                .navigationDestination(for: Step.self) { step in
                    destination(for: step)
                }
        }
        .onChange(of: model.session) { _, new in
            if new == .loggedIn, path.last == .signIn {
                push(.healthKitEssentials)
            }
        }
        .onAppear { restoreProgress() }
    }

    @ViewBuilder
    private func destination(for step: Step) -> some View {
        switch step {
        case .signIn:
            SignInStep { push(.healthKitEssentials) }
        case .healthKitEssentials:
            HealthKitWaveStep(wave: .essentials) { push(.healthKitActivity) }
        case .healthKitActivity:
            HealthKitWaveStep(wave: .activity) { push(.healthKitAdvanced) }
        case .healthKitAdvanced:
            HealthKitWaveStep(wave: .advanced) { push(.notifications) }
        case .notifications:
            NotificationsStep { push(.location) }
        case .location:
            LocationStep { push(.done) }
        case .done:
            DoneStep { finish() }
        }
    }

    private func push(_ step: Step) {
        path.append(step)
        UserDefaults(suiteName: "group.co.cronx.spark")?.set(step.rawValue, forKey: "onboarding.lastStep")
    }

    private func finish() {
        UserDefaults(suiteName: "group.co.cronx.spark")?.set(true, forKey: "onboarding.completed")
        isComplete = true
    }

    private func restoreProgress() {
        guard model.session == .loggedIn else { return }
        guard let raw = UserDefaults(suiteName: "group.co.cronx.spark")?.string(forKey: "onboarding.lastStep"),
              let last = Step(rawValue: raw)
        else { return }
        // Re-build the path up to and including the last step
        let ordered = Step.allCases
        guard let idx = ordered.firstIndex(of: last) else { return }
        path = Array(ordered[...idx])
    }
}
