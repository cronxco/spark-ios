import SparkKit
import SparkUI
import SwiftUI

struct SettingsRootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Label("Profile", systemImage: "person.circle")
                    }

                    Button(role: .destructive) {
                        Task { await appModel.signOut() }
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
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
        }
    }
}
