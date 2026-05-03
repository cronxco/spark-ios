import SparkUI
import SwiftUI
import UserNotifications

struct NotificationsStep: View {
    let proceed: () -> Void

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: SparkSpacing.xl) {
                Spacer().frame(height: SparkSpacing.xl)

                Image(systemName: "bell.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.sparkAccent)

                VStack(spacing: SparkSpacing.sm) {
                    Text("Stay in the loop")
                        .font(SparkFonts.display(.title, weight: .bold))
                    Text("Spark can notify you when baselines shift, your digest is ready, or an integration needs attention.")
                        .font(SparkTypography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: SparkSpacing.md) {
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
                .padding(.bottom, SparkSpacing.xxl)
            }
            .padding(.horizontal, SparkSpacing.xl)
        }
        .scrollContentBackground(.hidden)
        .background(Color.sparkSurface.ignoresSafeArea())
        .task { await refreshStatus() }
    }

    private func requestPermission() async {
        isRequesting = true
        defer { isRequesting = false }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        )) ?? false
        authStatus = granted ? .authorized : .denied
        if granted { proceed() }
    }

    private func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = settings.authorizationStatus
    }
}
