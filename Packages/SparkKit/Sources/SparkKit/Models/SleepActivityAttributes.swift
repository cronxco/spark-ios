// ActivityKit is iOS-only; watchOS targets skip this file.
#if os(iOS)
import ActivityKit
import Foundation

/// ActivityAttributes for the sleep Live Activity.
/// Shared between SparkApp (start/update) and SparkLiveActivities extension (render).
public struct SleepActivityAttributes: ActivityAttributes {
    public typealias ContentState = SleepContentState

    public struct SleepContentState: Codable, Hashable, Sendable {
        public enum Phase: String, Codable, Hashable, Sendable {
            case preparing
            case sleeping
            case wakingUp
            case resolved
        }

        public var phase: Phase
        public var startedAt: Date?
        public var sleepScore: Int?
        public var durationMinutes: Int?

        public var phaseLabel: String {
            switch phase {
            case .preparing: return "Getting ready for sleep"
            case .sleeping: return "Sleeping"
            case .wakingUp: return "Good morning ☀️"
            case .resolved:
                return sleepScore.map { "Sleep score: \($0)" } ?? "Sleep complete"
            }
        }

        public var durationDisplay: String? {
            guard let mins = durationMinutes else { return nil }
            let h = mins / 60
            let m = mins % 60
            return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        }

        public init(
            phase: Phase,
            startedAt: Date? = nil,
            sleepScore: Int? = nil,
            durationMinutes: Int? = nil
        ) {
            self.phase = phase
            self.startedAt = startedAt
            self.sleepScore = sleepScore
            self.durationMinutes = durationMinutes
        }
    }

    public var bedtime: Date
    public var targetWakeTime: Date?

    public init(bedtime: Date, targetWakeTime: Date? = nil) {
        self.bedtime = bedtime
        self.targetWakeTime = targetWakeTime
    }
}
#endif
