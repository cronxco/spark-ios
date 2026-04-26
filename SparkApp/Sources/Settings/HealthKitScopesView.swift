import SparkHealth
import SparkUI
import SwiftUI

struct HealthKitScopesView: View {
    @Environment(AppModel.self) private var appModel

    private var mgr: HealthKitPermissionManager { appModel.healthPermissions }

    var body: some View {
        List {
            if !mgr.isHealthAvailable {
                Section {
                    Text("Health data is not available on this device.")
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            } else {
                waveSection(
                    title: "Essentials",
                    subtitle: "Sleep, steps and heart rate",
                    state: mgr.essentialsState,
                    action: { Task { await mgr.requestEssentials() } }
                )

                waveSection(
                    title: "Activity",
                    subtitle: "Workouts, calories, distance and stand hours",
                    state: mgr.activityState,
                    action: { Task { await mgr.requestActivity() } }
                )

                waveSection(
                    title: "Advanced",
                    subtitle: "HRV, VO₂ max, respiratory rate and SpO₂",
                    state: mgr.advancedState,
                    action: { Task { await mgr.requestAdvanced() } }
                )

                Section {
                    Link(destination: URL(string: "x-apple-health://")!) {
                        Label("Manage in Health.app", systemImage: "heart.fill")
                    }
                }
            }
        }
        .navigationTitle("Health & Activity")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func waveSection(
        title: String,
        subtitle: String,
        state: HealthKitPermissionManager.AuthState,
        action: @escaping () -> Void
    ) -> some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(SparkTypography.body)
                    Text(subtitle)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                stateView(state, action: action)
            }
        }
    }

    @ViewBuilder
    private func stateView(
        _ state: HealthKitPermissionManager.AuthState,
        action: @escaping () -> Void
    ) -> some View {
        switch state {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.sparkSuccess)
        case .denied:
            Button("Denied", action: action)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(Color.sparkWarning)
        case .notDetermined:
            Button("Allow", action: action)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(Color.sparkAccent)
        }
    }
}
