// ActivityKit is iOS-only; watchOS targets skip this file.
#if os(iOS)
import ActivityKit
import Foundation

/// ActivityAttributes for the daily activity rings Live Activity.
/// Shared between SparkApp (start/update) and SparkLiveActivities extension (render).
public struct DailyActivityAttributes: ActivityAttributes {
    public typealias ContentState = DailyContentState

    public struct DailyContentState: Codable, Hashable, Sendable {
        public var steps: Int
        public var stepsGoal: Int
        public var moveProgress: Double
        public var exerciseProgress: Double
        public var standProgress: Double

        public var stepsDisplay: String {
            steps >= 1_000
                ? String(format: "%.1fk", Double(steps) / 1_000)
                : "\(steps)"
        }

        public init(
            steps: Int = 0,
            stepsGoal: Int = 10_000,
            moveProgress: Double = 0,
            exerciseProgress: Double = 0,
            standProgress: Double = 0
        ) {
            self.steps = steps
            self.stepsGoal = stepsGoal
            self.moveProgress = min(1, max(0, moveProgress))
            self.exerciseProgress = min(1, max(0, exerciseProgress))
            self.standProgress = min(1, max(0, standProgress))
        }
    }

    // Static context: the day this activity was started.
    public var startDate: Date

    public init(startDate: Date = .now) {
        self.startDate = startDate
    }
}
#endif
