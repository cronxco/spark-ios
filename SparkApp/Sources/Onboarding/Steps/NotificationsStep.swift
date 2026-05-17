import SparkUI
import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

struct NotificationsStep: View {
    let proceed: () -> Void

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false

    var body: some View {
        SparkOnboardingScaffold(
            icon: "bell.fill",
            title: "Stay in the loop",
            bodyText: "Spark can notify you when baselines shift, your digest is ready, or an integration needs attention."
        ) {
            EmptyView()
        } actions: {
            if authStatus == .authorized {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.sparkSuccess)
                    Text("Notifications enabled")
                        .font(SparkTypography.body)
                }
                PillButton("Continue", systemImage: "arrow.right.circle.fill", action: proceed)
            } else {
                PillButton("Allow notifications", systemImage: "bell.fill") {
                    Task { await requestPermission() }
                }
                .disabled(isRequesting)

                Button("Skip for now") { proceed() }
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }
        }
        .task { await refreshStatus() }
    }

    private func requestPermission() async {
        isRequesting = true
        defer { isRequesting = false }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        )) ?? false
        authStatus = granted ? .authorized : .denied
        if granted {
            #if canImport(UIKit)
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
            #endif
            proceed()
        }
    }

    private func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = settings.authorizationStatus
    }
}
