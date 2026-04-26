import SparkHealth
import SparkUI
import SwiftUI

struct HealthKitWaveStep: View {
    enum Wave {
        case essentials, activity, advanced

        var title: String {
            switch self {
            case .essentials: "Health Essentials"
            case .activity:   "Activity"
            case .advanced:   "Advanced Health"
            }
        }

        var icon: String {
            switch self {
            case .essentials: "heart.fill"
            case .activity:   "figure.walk"
            case .advanced:   "waveform.path.ecg"
            }
        }

        var why: String {
            switch self {
            case .essentials:
                "Spark uses sleep, steps and heart rate to build your daily health summary."
            case .activity:
                "Workouts, calories and stand hours power your activity rings and trends."
            case .advanced:
                "HRV, VO₂ max and SpO₂ help Spark detect recovery patterns and anomalies."
            }
        }

        var types: [String] {
            switch self {
            case .essentials: ["Sleep analysis", "Step count", "Heart rate"]
            case .activity:   ["Workouts", "Active energy", "Distance", "Exercise time", "Stand hours"]
            case .advanced:   ["Heart rate variability", "VO₂ max", "Respiratory rate", "Blood oxygen", "Mindfulness"]
            }
        }
    }

    let wave: Wave
    let proceed: () -> Void

    @Environment(AppModel.self) private var appModel

    private var mgr: HealthKitPermissionManager { appModel.healthPermissions }

    var body: some View {
        ScrollView {
            VStack(spacing: SparkSpacing.xl) {
                Spacer().frame(height: SparkSpacing.xl)

                Image(systemName: wave.icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.sparkAccent)

                VStack(spacing: SparkSpacing.sm) {
                    Text(wave.title)
                        .font(SparkFonts.display(.title, weight: .bold))
                    Text(wave.why)
                        .font(SparkTypography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                        ForEach(wave.types, id: \.self) { type in
                            HStack(spacing: SparkSpacing.sm) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.sparkAccent)
                                Text(type)
                                    .font(SparkTypography.body)
                            }
                        }
                    }
                }

                Spacer()

                VStack(spacing: SparkSpacing.md) {
                    if currentState == .granted {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.sparkSuccess)
                            Text("Access granted")
                                .font(SparkTypography.body)
                        }
                        PillButton("Continue", systemImage: "arrow.right.circle.fill", action: proceed)
                    } else {
                        PillButton("Allow \(wave.title)", systemImage: "heart.fill") {
                            Task {
                                await requestAuthorisation()
                                proceed()
                            }
                        }
                        Button("Skip for now") { proceed() }
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, SparkSpacing.xxl)
            }
            .padding(.horizontal, SparkSpacing.xl)
        }
        .scrollContentBackground(.hidden)
        .background(Color.sparkSurface.ignoresSafeArea())
    }

    private var currentState: HealthKitPermissionManager.AuthState {
        switch wave {
        case .essentials: mgr.essentialsState
        case .activity:   mgr.activityState
        case .advanced:   mgr.advancedState
        }
    }

    private func requestAuthorisation() async {
        switch wave {
        case .essentials: await mgr.requestEssentials()
        case .activity:   await mgr.requestActivity()
        case .advanced:   await mgr.requestAdvanced()
        }
    }
}
