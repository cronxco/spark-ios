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

    private nonisolated let logger = Logger(subsystem: "co.cronx.spark", category: "LiveActivity")

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
    }

    func endSleepActivity(score: Int, durationMinutes: Int) async {
        guard let activity = sleepActivity else { return }
        let resolvedState = SleepActivityAttributes.SleepContentState(
            phase: .resolved,
            sleepScore: score,
            durationMinutes: durationMinutes
        )
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
    }

    func endDailyActivity() async {
        guard let activity = dailyActivity else { return }
        await activity.end(
            .init(state: activity.content.state, staleDate: nil),
            dismissalPolicy: .immediate
        )
        cancelTokenTask(for: activity.id)
        dailyActivity = nil
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
                    _ = try await apiClient.request(
                        LiveActivitiesEndpoint.registerToken(
                            activityID: activityID,
                            token: tokenString,
                            type: activityType
                        )
                    )
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
    }
}
