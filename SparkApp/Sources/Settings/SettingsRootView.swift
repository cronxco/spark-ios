import SparkKit
import SparkUI
import SwiftUI

struct SettingsRootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Manage your account, preferences, connections, and app diagnostics.")
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, SparkSpacing.sm)
                }
                .listRowBackground(Color.clear)

                Section("Account") {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Label("Profile", systemImage: "person.circle")
                    }

                    Button(role: .destructive) {
                        showsSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section("Preferences") {
                    NavigationLink {
                        NotificationsPreferencesView()
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }

                    NavigationLink {
                        HealthKitScopesView()
                    } label: {
                        Label("Health & Activity", systemImage: "heart.fill")
                    }
                }

                Section("Connections") {
                    NavigationLink {
                        IntegrationsListView()
                    } label: {
                        Label("Integrations", systemImage: "link")
                    }
                }

                Section("Security") {
                    NavigationLink {
                        DevicesView()
                    } label: {
                        Label("Devices", systemImage: "iphone")
                    }

                    NavigationLink {
                        ApiTokensView()
                    } label: {
                        Label("API Tokens", systemImage: "key.fill")
                    }
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }

                    #if DEBUG
                    NavigationLink {
                        DebugView()
                    } label: {
                        Label("Debug", systemImage: "ladybug")
                    }
                    #endif
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Sign out of Spark?",
                isPresented: $showsSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task { await appModel.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your cached data on this device will be removed.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}
