import Foundation
import OSLog
import SparkKit
import SwiftData
import WidgetKit

#if canImport(UIKit)
import UIKit
#endif

/// Handles `aps.content-available = 1` silent push notifications.
///
/// The completion handler is called exactly once — either when the delta sync
/// finishes, or after 24 s if the sync hasn't completed (leaving 1 s before
/// the OS terminates the background task at 25 s).
///
/// Wire in `SparkAppDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`.
public enum SilentPushHandler {
    private static let logger = Logger(subsystem: "co.cronx.spark", category: "SilentPush")
    private static let signposter = OSSignposter(logger: logger)

    /// All mutable handler state lives on the MainActor — both tasks are
    /// Task { @MainActor in } so the flag is always read/written serially.
    @MainActor
    private final class State {
        var completed = false
        // Completion is always called from @MainActor — @Sendable not required.
        let completion: (UIBackgroundFetchResult) -> Void

        init(completion: @escaping (UIBackgroundFetchResult) -> Void) {
            self.completion = completion
        }

        func finish(_ result: UIBackgroundFetchResult) {
            guard !completed else { return }
            completed = true
            completion(result)
        }
    }

    @MainActor
    public static func handle(
        userInfo: [AnyHashable: Any],
        apiClient: APIClient,
        container: ModelContainer,
        completion: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let aps = userInfo["aps"] as? [String: Any]
        guard aps?["content-available"] as? Int == 1 else {
            completion(.noData)
            return
        }

        let signpostState = signposter.beginInterval("SilentPush")
        let state = State(completion: completion)

        // Budget watchdog — fires if sync doesn't finish within 24 s.
        let budgetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(24))
            guard !Task.isCancelled else { return }
            logger.warning("Silent push budget exceeded")
            state.finish(.noData)
        }

        // Primary sync task.
        Task { @MainActor in
            defer {
                budgetTask.cancel()
                signposter.endInterval("SilentPush", signpostState)
            }
            let changed = await DeltaSyncer.sync(using: apiClient, container: container)
            WidgetCenter.shared.reloadAllTimelines()
            logger.info("Silent push handled, changed=\(changed, privacy: .public)")
            state.finish(changed ? .newData : .noData)
        }
    }
}
