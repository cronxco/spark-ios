#if DEBUG
import SparkKit
import SparkSync
import SparkUI
import SwiftData
import SwiftUI
import UserNotifications
import WidgetKit

struct DebugView: View {
    @Environment(AppModel.self) private var appModel

    @State private var cacheResetConfirm = false
    @State private var statusMessage: String?

    // Push notifications
    @State private var isReregistering = false
    @State private var isSendingTestPush = false

    // WebSocket
    @State private var wsConnected: Bool?
    @State private var wsSocketId: String?
    @State private var isReconnecting = false

    // Environment
    @State private var selectedEnv: EnvironmentOption = .current
    @State private var envChanged = false

    // Sync cursors
    @State private var syncCursors: [SyncCursor] = []

    // Notification permission
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined

    // Timezone prompt
    @State private var timezoneEndpointState: TimezoneEndpointDebugState = .notLoaded
    @State private var isRefreshingTimezone = false

    var body: some View {
        List {
            cacheSection
            pushSection
            websocketSection
            environmentSection
            syncCursorSection
            notificationPermissionSection
            timezoneSection
            widgetSection
            loggingSection

            if let msg = statusMessage {
                Section {
                    Text(msg)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(statusMessageColor(for: msg))
                }
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAll() }
    }

    // MARK: - Sections

    private var cacheSection: some View {
        Section("Cache") {
            Button("Reset SwiftData cache") { cacheResetConfirm = true }
                .foregroundStyle(Color.sparkError)
                .confirmationDialog(
                    "Reset cache?",
                    isPresented: $cacheResetConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) { resetCache() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("All locally cached data will be deleted. It will re-sync on next launch.")
                }
        }
    }

    private var pushSection: some View {
        Section("Push Notifications") {
            let token = UserDefaults.sparkAppGroup.string(forKey: "spark.apnsToken")
            if let token {
                Button {
                    UIPasteboard.general.string = token
                    statusMessage = "APNs token copied."
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("APNs Token")
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                        Text(token)
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text("No APNs token registered yet.")
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }

            Button(isReregistering ? "Re-registering…" : "Re-register device") {
                isReregistering = true
                Task {
                    await appModel.registerDevice()
                    isReregistering = false
                    statusMessage = "Device re-registered."
                }
            }
            .disabled(isReregistering || token == nil)

            Button(isSendingTestPush ? "Sending…" : "Send test push") {
                isSendingTestPush = true
                Task {
                    do {
                        try await appModel.sendTestPush()
                        statusMessage = "Test push sent."
                    } catch {
                        statusMessage = "Test push failed: \(debugErrorMessage(error))"
                    }
                    isSendingTestPush = false
                }
            }
            .disabled(isSendingTestPush || token == nil)
        }
    }

    private var websocketSection: some View {
        Section("WebSocket (Reverb)") {
            HStack {
                Circle()
                    .fill(wsStatusColor)
                    .frame(width: 8, height: 8)
                Text(wsStatusLabel)
                    .font(SparkTypography.body)
                Spacer()
                Button("Refresh") { Task { await refreshWS() } }
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(Color.sparkAccent)
            }

            if let socketId = wsSocketId {
                Button {
                    UIPasteboard.general.string = socketId
                    statusMessage = "Socket ID copied."
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Socket ID")
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                        Text(socketId)
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
            }

            Button(isReconnecting ? "Reconnecting…" : "Reconnect") {
                isReconnecting = true
                Task {
                    await appModel.reverb.disconnect()
                    await appModel.reverbConnect()
                    await refreshWS()
                    isReconnecting = false
                    statusMessage = "WebSocket reconnected."
                }
            }
            .disabled(isReconnecting)
        }
    }

    private var environmentSection: some View {
        Section("Environment") {
            Picker("Environment", selection: $selectedEnv) {
                ForEach(EnvironmentOption.allCases) { env in
                    Text(env.displayName).tag(env)
                }
            }
            .onChange(of: selectedEnv) { _, new in
                new.apply()
                envChanged = new != .current
                statusMessage = "Environment set to \(new.displayName). Restart to apply."
            }

            if envChanged {
                Text("Restart required for environment change to take effect.")
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(Color.sparkWarning)
            }
        }
    }

    private var syncCursorSection: some View {
        Section("Sync Cursors") {
            if syncCursors.isEmpty {
                Text("No sync cursors stored.")
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(syncCursors, id: \.resource) { cursor in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cursor.resource)
                            .font(SparkTypography.bodySmall)
                        if let value = cursor.cursor {
                            Text(value)
                                .font(SparkTypography.monoSmall)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        if let date = cursor.lastSyncedAt {
                            Text(date.formatted(.relative(presentation: .named)))
                                .font(SparkTypography.monoSmall)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Button("Clear all cursors", role: .destructive) {
                clearSyncCursors()
            }
            .disabled(syncCursors.isEmpty)
        }
    }

    private var notificationPermissionSection: some View {
        Section("Notification Permission") {
            HStack {
                Circle()
                    .fill(notifStatusColor)
                    .frame(width: 8, height: 8)
                Text(notifStatusLabel)
                    .font(SparkTypography.body)
                Spacer()
                Button("Refresh") { Task { await refreshNotifStatus() } }
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(Color.sparkAccent)
            }

            if notifStatus == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundStyle(Color.sparkAccent)
            }
        }
    }

    private var timezoneSection: some View {
        Section("Timezone Prompt") {
            debugValue("Session", value: String(describing: appModel.session))
            debugValue("Profile", value: appModel.profile?.timezone ?? "nil")
            debugValue("Device", value: TimeZone.autoupdatingCurrent.identifier)
            debugValue("Cached server value", value: appModel.timezoneState?.timezone ?? "nil")
            debugValue("Prompt in model", value: timezonePromptDescription)
            debugValue("Stored rejection", value: rejectedTimezonePair ?? "nil")

            switch timezoneEndpointState {
            case .notLoaded:
                debugValue("Direct endpoint", value: "Not loaded")
            case .loaded(let state):
                debugValue("Direct endpoint", value: state.timezone)
                debugValue("Source", value: state.source)
                debugValue(
                    "Acknowledged",
                    value: state.acknowledgedAt?.formatted(.iso8601) ?? "nil"
                )
                debugValue("Endpoint device ID", value: state.deviceId ?? "nil")
                debugValue(
                    "Policy result",
                    value: timezonePolicyDescription(for: state.timezone)
                )
            case .failed(let message):
                debugValue("Direct endpoint error", value: message, color: .sparkError)
            }

            Button(isRefreshingTimezone ? "Checking…" : "Refresh diagnostics") {
                Task { await refreshTimezoneDiagnostics() }
            }
            .disabled(isRefreshingTimezone)

            Button("Force prompt check") {
                Task {
                    await appModel.reconsiderTimezoneChange()
                    await refreshTimezoneDiagnostics()
                    statusMessage = appModel.timezonePrompt == nil
                        ? "Forced timezone check completed without creating a prompt."
                        : "Timezone prompt created."
                }
            }

            Button("Clear stored rejection", role: .destructive) {
                UserDefaults.sparkAppGroup.removeObject(forKey: "spark.timezone.rejectedPair")
                statusMessage = "Stored timezone rejection cleared."
            }
            .disabled(rejectedTimezonePair == nil)
        }
    }

    private var widgetSection: some View {
        Section("Widgets") {
            Button("Reload all widget timelines") {
                WidgetCenter.shared.reloadAllTimelines()
                statusMessage = "Widget timelines reloaded."
            }
        }
    }

    private var loggingSection: some View {
        Section("Logging") {
            Button("Force re-onboard") {
                UserDefaults.sparkAppGroup.set(false, forKey: "onboarding.completed")
                UserDefaults.sparkAppGroup.removeObject(forKey: "onboarding.lastStep")
                statusMessage = "Onboarding reset — restart app."
            }
            .foregroundStyle(Color.sparkWarning)

            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                Text("OSLog is not queryable in-app without entitlements.")
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
                Text("Open Console.app on Mac and filter by subsystem: co.cronx.sparkapp")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private var wsStatusColor: Color {
        guard let connected = wsConnected else { return .gray }
        return connected ? Color.sparkSuccess : Color.sparkError
    }

    private var wsStatusLabel: String {
        guard let connected = wsConnected else { return "Unknown" }
        return connected ? "Connected" : "Disconnected"
    }

    private var notifStatusColor: Color {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return Color.sparkSuccess
        case .denied: return Color.sparkError
        default: return .gray
        }
    }

    private var notifStatusLabel: String {
        switch notifStatus {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .notDetermined: return "Not determined"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private var rejectedTimezonePair: String? {
        UserDefaults.sparkAppGroup.string(forKey: "spark.timezone.rejectedPair")
    }

    private var timezonePromptDescription: String {
        guard let prompt = appModel.timezonePrompt else { return "nil" }
        return "\(prompt.acknowledgedTimezone) → \(prompt.deviceTimezone)"
    }

    // MARK: - Actions

    private func loadAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await refreshWS() }
            group.addTask { await refreshNotifStatus() }
            group.addTask { await refreshTimezoneDiagnostics() }
            group.addTask { await MainActor.run { loadSyncCursors() } }
        }
    }

    private func refreshWS() async {
        let status = await appModel.reverb.connectionStatus()
        wsConnected = status.isConnected
        wsSocketId = status.socketId
    }

    private func refreshNotifStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notifStatus = settings.authorizationStatus
    }

    private func refreshTimezoneDiagnostics() async {
        guard !isRefreshingTimezone else { return }
        isRefreshingTimezone = true
        defer { isRefreshingTimezone = false }

        do {
            timezoneEndpointState = .loaded(
                try await appModel.apiClient.request(CheckInsEndpoint.timezone())
            )
        } catch {
            timezoneEndpointState = .failed(debugErrorMessage(error))
        }
    }

    private func loadSyncCursors() {
        let descriptor = FetchDescriptor<SyncCursor>(sortBy: [SortDescriptor(\.resource)])
        syncCursors = (try? appModel.container.mainContext.fetch(descriptor)) ?? []
    }

    private func clearSyncCursors() {
        let context = appModel.container.mainContext
        for cursor in syncCursors {
            context.delete(cursor)
        }
        try? context.save()
        syncCursors = []
        statusMessage = "Sync cursors cleared. Next sync will be a full fetch."
    }

    private func resetCache() {
        Task {
            do {
                let context = appModel.container.mainContext
                try context.delete(model: CachedEvent.self)
                try context.delete(model: CachedObject.self)
                try context.delete(model: CachedBlock.self)
                try context.delete(model: CachedIntegration.self)
                try context.delete(model: CachedPlace.self)
                try context.delete(model: CachedMetric.self)
                try context.delete(model: CachedAnomaly.self)
                try context.delete(model: CachedDaySummary.self)
                try context.delete(model: CachedNotification.self)
                try? context.save()
                await appModel.etagCache.clearAll()
                statusMessage = "Cache cleared."
            } catch {
                statusMessage = "Error: \(debugErrorMessage(error))"
            }
        }
    }

    private func statusMessageColor(for message: String) -> Color {
        if message.localizedCaseInsensitiveContains("failed")
            || message.localizedCaseInsensitiveContains("error") {
            return Color.sparkError
        }
        return Color.sparkSuccess
    }

    private func debugErrorMessage(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func timezonePolicyDescription(for acknowledgedTimezone: String) -> String {
        let shouldPrompt = TimezoneChangePolicy.shouldPrompt(
            acknowledgedTimezone: acknowledgedTimezone,
            deviceTimezone: TimeZone.autoupdatingCurrent.identifier,
            rejectedKey: rejectedTimezonePair
        )
        return shouldPrompt ? "Should prompt" : "Suppressed"
    }

    private func debugValue(
        _ label: String,
        value: String,
        color: Color = .secondary
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(SparkTypography.bodySmall)
            Text(value.replacingOccurrences(of: "\n", with: " → "))
                .font(SparkTypography.monoSmall)
                .foregroundStyle(color)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}

private enum TimezoneEndpointDebugState {
    case notLoaded
    case loaded(TimezoneAcknowledgement)
    case failed(String)
}

// MARK: - Environment option

private enum EnvironmentOption: String, CaseIterable, Identifiable {
    case production, staging

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    static var current: Self {
        let name = UserDefaults.sparkAppGroup.string(forKey: "spark.env.name") ?? "production"
        return Self(rawValue: name) ?? .production
    }

    func apply() {
        let defaults = UserDefaults.sparkAppGroup
        switch self {
        case .production:
            defaults.removeObject(forKey: "spark.env.baseURL")
            defaults.removeObject(forKey: "spark.env.oauthURL")
            defaults.removeObject(forKey: "spark.env.name")
            defaults.removeObject(forKey: "spark.env.reverbHost")
            defaults.removeObject(forKey: "spark.env.reverbAppKey")
            defaults.removeObject(forKey: "spark.env.reverbPort")
            defaults.removeObject(forKey: "spark.env.reverbUseTLS")
        case .staging:
            defaults.set("https://staging.spark.cronx.co/api/v1/mobile", forKey: "spark.env.baseURL")
            defaults.set("https://staging.spark.cronx.co/oauth/authorize", forKey: "spark.env.oauthURL")
            defaults.set("staging", forKey: "spark.env.name")
        }
    }
}
#endif
