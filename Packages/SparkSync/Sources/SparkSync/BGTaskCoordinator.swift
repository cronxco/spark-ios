import BackgroundTasks
import Foundation
import OSLog
import SparkKit
import SwiftData
import WidgetKit

/// Manages the two background task identifiers Spark registers with the OS.
///
/// `co.cronx.spark.refresh`  — BGAppRefreshTask, fires ~every 2 h.
///   Fetches /sync/delta, writes to SwiftData, reloads widget timelines.
///
/// `co.cronx.spark.prefetch` — BGProcessingTask, fires nightly when on
///   power + Wi-Fi. Runs the optional Spotlight indexing closure provided
///   by the app target, then pre-warms image caches.
///
/// **Registration must happen synchronously during app launch** — call
/// `BGTaskCoordinator.register(...)` inside `SparkAppDelegate.application(_:didFinishLaunchingWithOptions:)`
/// or `SparkApp.init()` before the method returns.
public enum BGTaskCoordinator {
    public static let refreshTaskIdentifier = "co.cronx.spark.refresh"
    public static let prefetchTaskIdentifier = "co.cronx.spark.prefetch"

    private static let logger = Logger(subsystem: "co.cronx.spark", category: "BGTask")

    // MARK: - Registration

    /// Register task handlers with BGTaskScheduler. Must be called during launch.
    /// - Parameters:
    ///   - apiClient: Called lazily when the task fires to obtain the API client.
    ///   - container: Called lazily when the task fires to obtain the SwiftData container.
    ///   - onPrefetch: Optional additional work to run during the prefetch task
    ///     (e.g. Spotlight indexing). The closure is `@Sendable` and async.
    public static func register(
        apiClient: @escaping @Sendable () async -> APIClient?,
        container: @escaping @Sendable () throws -> ModelContainer,
        onPrefetch: (@Sendable () async -> Void)? = nil
    ) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            handleRefresh(task: task, apiClient: apiClient, container: container)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: prefetchTaskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else { return }
            handlePrefetch(task: task, container: container, onPrefetch: onPrefetch)
        }
    }

    // MARK: - Scheduling

    /// Submit a BGAppRefreshTaskRequest so the OS wakes the app in ~2 h.
    public static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Submit a BGProcessingTaskRequest for nightly prefetch (power + network required).
    public static func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: prefetchTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        request.earliestBeginDate = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 3, minute: 0),
            matchingPolicy: .nextTime
        )
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Handlers

    private static func handleRefresh(
        task: BGAppRefreshTask,
        apiClient: @escaping @Sendable () async -> APIClient?,
        container: @escaping @Sendable () throws -> ModelContainer
    ) {
        logger.info("BGAppRefreshTask began: \(task.identifier, privacy: .public)")

        // BGAppRefreshTask is not Sendable but setTaskCompleted is documented
        // thread-safe — suppress the isolation check.
        nonisolated(unsafe) let taskRef = task

        let workTask = Task { @MainActor in
            defer {
                scheduleAppRefresh()
                logger.info("BGAppRefreshTask completed")
            }
            guard
                let client = await apiClient(),
                let cont = try? container()
            else {
                taskRef.setTaskCompleted(success: false)
                return
            }
            let changed = await DeltaSyncer.sync(using: client, container: cont)
            WidgetCenter.shared.reloadAllTimelines()
            taskRef.setTaskCompleted(success: true)
            logger.info("Delta sync result: changed=\(changed, privacy: .public)")
        }

        task.expirationHandler = {
            workTask.cancel()
            taskRef.setTaskCompleted(success: false)
        }
    }

    private static func handlePrefetch(
        task: BGProcessingTask,
        container: @escaping @Sendable () throws -> ModelContainer,
        onPrefetch: (@Sendable () async -> Void)?
    ) {
        logger.info("BGProcessingTask began: \(task.identifier, privacy: .public)")

        // Same rationale as handleRefresh — BGProcessingTask is not Sendable.
        nonisolated(unsafe) let taskRef = task

        let workTask = Task { @MainActor in
            defer {
                scheduleProcessingTask()
                logger.info("BGProcessingTask completed")
            }
            if let extra = onPrefetch {
                await extra()
            }
            taskRef.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            workTask.cancel()
            taskRef.setTaskCompleted(success: false)
        }
    }
}
