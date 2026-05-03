import Foundation
import SparkKit
import SwiftData

/// Strongly-typed projection of today's cached DaySummary for widget rendering.
/// Constructed entirely from SwiftData — no network calls from widget code.
struct WidgetDataSnapshot: Sendable {
    // Health
    let sleepScore: Int?
    let sleepDurationMinutes: Int?

    // Activity rings
    let steps: Int?
    let stepsGoal: Int
    let moveProgress: Double
    let exerciseProgress: Double
    let standProgress: Double

    // Money
    let spentToday: Double?
    let currency: String

    // Calendar
    let nextEventTitle: String?
    let nextEventStart: String?
    let nextEventLocation: String?

    // Anomalies (for dashboard widget)
    let anomalies: [Anomaly]

    // When this snapshot was read
    let date: Date

    // MARK: - Placeholder

    static let placeholder = WidgetDataSnapshot(
        sleepScore: 84,
        sleepDurationMinutes: 7 * 60 + 23,
        steps: 6_210,
        stepsGoal: 10_000,
        moveProgress: 0.62,
        exerciseProgress: 0.40,
        standProgress: 0.75,
        spentToday: 24.50,
        currency: "GBP",
        nextEventTitle: "Team standup",
        nextEventStart: "09:30",
        nextEventLocation: nil,
        anomalies: [],
        date: .now
    )

    // MARK: - Fetch from SwiftData

    static func fetchToday() async -> WidgetDataSnapshot {
        guard let container = try? SparkDataStore.makeContainer() else {
            return .placeholder
        }
        let context = ModelContext(container)
        let dateStr = Self.todayDateString()
        let descriptor = FetchDescriptor<CachedDaySummary>(
            predicate: #Predicate { $0.date == dateStr }
        )
        let summary = (try? context.fetch(descriptor).first).flatMap { try? $0.decoded() }
        return WidgetDataSnapshot(date: .now, summary: summary)
    }

    // MARK: - Decode from DaySummary

    init(date: Date, summary: DaySummary?) {
        self.date = date

        let health = summary?.sections.health?.objectValue
        sleepScore = health?["sleep_score"]?.objectValue?["score"]?.intValue
        let durSec = health?["sleep_duration"]?.objectValue?["duration_seconds"]?.intValue
        sleepDurationMinutes = durSec.map { $0 / 60 }

        let activity = summary?.sections.activity?.objectValue
        let stepsObj = activity?["steps"]?.objectValue
        steps = stepsObj?["value"]?.intValue
        stepsGoal = stepsObj?["goal"]?.intValue ?? 10_000
        let kcal = activity?["active_energy_kcal"]?.objectValue?["value"]?.intValue ?? 0
        let kcalGoal = activity?["active_energy_kcal"]?.objectValue?["goal"]?.intValue ?? 600
        moveProgress = min(1.0, Double(kcal) / Double(kcalGoal))
        let ex = activity?["exercise_minutes"]?.objectValue?["value"]?.intValue ?? 0
        let exGoal = activity?["exercise_minutes"]?.objectValue?["goal"]?.intValue ?? 30
        exerciseProgress = min(1.0, Double(ex) / Double(exGoal))
        let stand = activity?["stand_hours"]?.objectValue?["value"]?.intValue ?? 0
        let standGoal = activity?["stand_hours"]?.objectValue?["goal"]?.intValue ?? 12
        standProgress = min(1.0, Double(stand) / Double(standGoal))

        let money = summary?.sections.money?.objectValue
        spentToday = money?["total_spend"]?.doubleValue
        let firstTx = money?["transactions"]?.arrayValue?.first?.objectValue
        currency = firstTx?["currency"]?.stringValue ?? "GBP"

        nextEventTitle = nil
        nextEventStart = nil
        nextEventLocation = nil

        anomalies = summary?.anomalies ?? []
    }

    // Internal designated init (for placeholder + tests).
    init(
        sleepScore: Int?,
        sleepDurationMinutes: Int?,
        steps: Int?,
        stepsGoal: Int,
        moveProgress: Double,
        exerciseProgress: Double,
        standProgress: Double,
        spentToday: Double?,
        currency: String,
        nextEventTitle: String?,
        nextEventStart: String?,
        nextEventLocation: String?,
        anomalies: [Anomaly],
        date: Date
    ) {
        self.sleepScore = sleepScore
        self.sleepDurationMinutes = sleepDurationMinutes
        self.steps = steps
        self.stepsGoal = stepsGoal
        self.moveProgress = moveProgress
        self.exerciseProgress = exerciseProgress
        self.standProgress = standProgress
        self.spentToday = spentToday
        self.currency = currency
        self.nextEventTitle = nextEventTitle
        self.nextEventStart = nextEventStart
        self.nextEventLocation = nextEventLocation
        self.anomalies = anomalies
        self.date = date
    }

    // MARK: - Helpers

    var sleepDurationDisplay: String? {
        guard let mins = sleepDurationMinutes else { return nil }
        let h = mins / 60
        let m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    var stepsDisplay: String {
        guard let s = steps else { return "—" }
        return s >= 1_000 ? String(format: "%.1fk", Double(s) / 1_000) : "\(s)"
    }

    var spentTodayDisplay: String? {
        guard let amount = spentToday else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: abs(amount)))
    }

    private static func todayDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }
}
