@preconcurrency import ActivityKit
import Foundation
import OSLog
import SparkKit

/// Manages the lifecycle of Spark Live Activities: start, update, end,
/// and push-token registration with the backend.
@MainActor
@Observable
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var sleepActivity: Activity<SleepActivityAttributes>?
    private var dailyActivity: Activity<DailyActivityAttributes>?
    private var tokenTasks: [String: Task<Void, Never>] = [:]
    private var registeredActivityIDs = Set<String>()
    private var serverActivityIDs: [String: String] = [:]
    private var serverUpdateTimes: [String: [Date]] = [:]

    private nonisolated let logger = Logger(subsystem: "co.cronx.sparkapp", category: "LiveActivity")

    // MARK: - Sleep LA

    func startSleepActivity(bedtime: Date, targetWakeTime: Date?) async {
        guard sleepActivity == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activities disabled by user")
            return
        }

        let attributes = SleepActivityAttributes(bedtime: bedtime, targetWakeTime: targetWakeTime)
        let initialState = SleepActivityAttributes.SleepContentState(phase: .preparing)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: .token
            )
            sleepActivity = activity
            logger.info("Started sleep Live Activity \(activity.id)")
            let apiClient = AppModel.shared.apiClient
            observePushTokens(for: activity, type: "sleep", apiClient: apiClient)
        } catch {
            logger.error("Failed to start sleep LA: \(error)")
        }
    }

    func updateSleepActivity(state: SleepActivityAttributes.SleepContentState) async {
        guard let activity = sleepActivity else { return }
        await activity.update(.init(state: state, staleDate: nil))
        await mirrorUpdate(state, for: activity)
    }

    func endSleepActivity(score: Int, durationMinutes: Int) async {
        guard let activity = sleepActivity else { return }
        let resolvedState = SleepActivityAttributes.SleepContentState(
            phase: .resolved,
            sleepScore: score,
            durationMinutes: durationMinutes
        )
        // Tell the server before clearing local state so it can issue its
        // remote end request while it still has the activity record.
        await endServerActivity(id: activity.id)
        await activity.end(
            .init(state: resolvedState, staleDate: nil),
            dismissalPolicy: .after(.now.addingTimeInterval(60))
        )
        cancelTokenTask(for: activity.id)
        sleepActivity = nil
    }

    // MARK: - Daily Activity Rings LA

    func startDailyActivity() async {
        guard dailyActivity == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = DailyActivityAttributes()
        let initialState = DailyActivityAttributes.DailyContentState()

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: .token
            )
            dailyActivity = activity
            logger.info("Started daily activity Live Activity \(activity.id)")
            let apiClient = AppModel.shared.apiClient
            observePushTokens(for: activity, type: "daily", apiClient: apiClient)
        } catch {
            logger.error("Failed to start daily activity LA: \(error)")
        }
    }

    func updateDailyActivity(state: DailyActivityAttributes.DailyContentState) async {
        guard let activity = dailyActivity else { return }
        await activity.update(.init(state: state, staleDate: nil))
        await mirrorUpdate(state, for: activity)
    }

    func endDailyActivity() async {
        guard let activity = dailyActivity else { return }
        await endServerActivity(id: activity.id)
        await activity.end(
            .init(state: activity.content.state, staleDate: nil),
            dismissalPolicy: .immediate
        )
        cancelTokenTask(for: activity.id)
        dailyActivity = nil
    }

    // MARK: - Sign-out

    /// Ends every Live Activity Spark owns and cancels its token observers.
    ///
    /// Live Activities outlive the app process and render on the Lock Screen,
    /// so one left running after sign-out shows the departing user's sleep or
    /// activity data to whoever holds the device.
    func endAll() async {
        if let activity = sleepActivity {
            await activity.end(
                .init(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
            cancelTokenTask(for: activity.id)
            sleepActivity = nil
        }

        if let activity = dailyActivity {
            await activity.end(
                .init(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
            cancelTokenTask(for: activity.id)
            dailyActivity = nil
        }

        // Activities started by a previous launch are not held in memory, so
        // sweep whatever ActivityKit still reports as running.
        for activity in Activity<SleepActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        for activity in Activity<DailyActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        for task in tokenTasks.values {
            task.cancel()
        }
        tokenTasks.removeAll()
    }

    // MARK: - Push token observation

    private func observePushTokens<A: ActivityAttributes>(
        for activity: Activity<A>,
        type activityType: String,
        apiClient: APIClient
    ) {
        let activityID = activity.id
        let log = logger
        let task = Task {
            for await tokenData in activity.pushTokenUpdates {
                let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
                do {
                    if !self.registeredActivityIDs.contains(activityID) {
                        let record = try await apiClient.request(
                            LiveActivitiesEndpoint.create(
                                activityID: activityID,
                                token: tokenString,
                                type: activityType,
                                contentState: activity.content.state
                            )
                        )
                        self.serverActivityIDs[activityID] = record.id
                        self.registeredActivityIDs.insert(activityID)
                    } else {
                        guard let serverID = self.serverActivityIDs[activityID] else { continue }
                        _ = try await apiClient.request(
                            LiveActivitiesEndpoint.registerToken(
                                activityID: serverID,
                                token: tokenString
                            )
                        )
                    }
                    log.info("Registered LA push token for \(activityID)")
                } catch {
                    log.error("Failed to register LA token: \(error)")
                }
            }
        }
        tokenTasks[activityID] = task
    }

    private func cancelTokenTask(for activityID: String) {
        tokenTasks[activityID]?.cancel()
        tokenTasks.removeValue(forKey: activityID)
        registeredActivityIDs.remove(activityID)
        serverActivityIDs.removeValue(forKey: activityID)
        serverUpdateTimes.removeValue(forKey: activityID)
    }

    private func mirrorUpdate<A: ActivityAttributes>(
        _ state: A.ContentState,
        for activity: Activity<A>
    ) async where A.ContentState: Encodable & Sendable {
        guard let serverID = serverActivityIDs[activity.id] else { return }
        let now = Date()
        let cutoff = now.addingTimeInterval(-3600)
        let recent = (serverUpdateTimes[activity.id] ?? []).filter { $0 >= cutoff }
        guard recent.count < 16 else {
            logger.notice("Skipping server Live Activity update; hourly limit reached")
            serverUpdateTimes[activity.id] = recent
            return
        }
        serverUpdateTimes[activity.id] = recent + [now]
        do {
            _ = try await AppModel.shared.apiClient.request(
                LiveActivitiesEndpoint.update(activityID: serverID, state: state)
            )
        } catch {
            // The local ActivityKit update already succeeded. Server mirroring
            // is best-effort and must never degrade the lock-screen activity.
            logger.error("Failed to mirror Live Activity update: \(error)")
        }
    }

    private func endServerActivity(id: String) async {
        guard let serverID = serverActivityIDs[id] else { return }
        do {
            _ = try await AppModel.shared.apiClient.request(LiveActivitiesEndpoint.end(activityID: serverID))
        } catch {
            logger.error("Failed to end server Live Activity: \(error)")
        }
    }
}
