import SparkUI
import SwiftUI

/// Holds the Settings tab until the full tree lands in Week 3 of Phase 2.
/// Keeps Sign Out reachable so dogfood builds can rotate accounts.
struct SettingsPlaceholderView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Profile, notifications, integrations, HealthKit scopes, devices, API tokens, About, and Debug land in Week 3 of Phase 2.")
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        Task { await appModel.signOut() }
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("Account")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
