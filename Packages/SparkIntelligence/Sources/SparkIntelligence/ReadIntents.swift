import AppIntents
import Foundation
import SparkKit

// MARK: - Get Sleep Score

public struct GetSleepScoreIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Sleep Score"
    public static let description = IntentDescription("Get your sleep score for today.")

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<Int?> & ProvidesDialog {
        let snapshot = await IntentService().todaySnapshot()
        let score = snapshot?.sleepScore
        let dur = snapshot?.sleepDurationDisplay ?? "unknown duration"
        let dialog: IntentDialog = score.map {
            "Your sleep score is \($0) out of 100. You slept \(dur)."
        } ?? "No sleep data available for today yet."
        return .result(value: score, dialog: dialog)
    }
}

// MARK: - Get Steps Today

public struct GetStepsTodayIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Steps Today"
    public static let description = IntentDescription("Get your step count for today.")

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<Int?> & ProvidesDialog {
        let snapshot = await IntentService().todaySnapshot()
        let steps = snapshot?.steps
        let goal = snapshot?.stepsGoal ?? 10_000
        let dialog: IntentDialog = steps.map {
            let pct = Int(Double($0) / Double(goal) * 100)
            return "You've taken \($0) steps today, which is \(pct)% of your \(goal) step goal."
        } ?? "No step data available yet."
        return .result(value: steps, dialog: dialog)
    }
}

// MARK: - Get Spend Today

public struct GetSpendTodayIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Daily Spend"
    public static let description = IntentDescription("Get how much you've spent today.")

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<Double?> & ProvidesDialog {
        let snapshot = await IntentService().todaySnapshot()
        let amount = snapshot?.spentToday
        let dialog: IntentDialog = snapshot.map {
            "You've spent \($0.spentDisplay) today."
        } ?? "No spending data available yet."
        return .result(value: amount, dialog: dialog)
    }
}

// MARK: - Get Readiness

public struct GetReadinessIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Readiness"
    public static let description = IntentDescription("Get your daily readiness score based on sleep and recovery.")

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<Int?> & ProvidesDialog {
        let snapshot = await IntentService().todaySnapshot()
        // Readiness is proxied by sleep score until a dedicated readiness
        // endpoint ships on the backend.
        let score = snapshot?.sleepScore
        let dialog: IntentDialog = score.map {
            "Your readiness score today is \($0) out of 100."
        } ?? "No readiness data available yet."
        return .result(value: score, dialog: dialog)
    }
}
