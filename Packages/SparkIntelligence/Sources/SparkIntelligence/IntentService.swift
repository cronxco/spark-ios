import Foundation
import SparkKit
import SwiftData

/// Shared service providing API access and SwiftData reads to AppIntents.
/// Constructed on-demand in each intent's `perform()` — intents may run in
/// the extension process where `AppModel.shared` is not available.
@MainActor
public struct IntentService {
    public let apiClient: APIClient
    private let tokenStore: KeychainTokenStore

    public init() {
        let store = KeychainTokenStore()
        let cache = ETagCache()
        self.tokenStore = store
        self.apiClient = APIClient(tokenStore: store, etagCache: cache)
    }

    // MARK: - SwiftData reads

    public func todaySnapshot() -> TodayIntentSnapshot? {
        guard let container = try? SparkDataStore.makeContainer() else { return nil }
        let context = ModelContext(container)
        let dateStr = todayDateString()
        let descriptor = FetchDescriptor<CachedDaySummary>(
            predicate: #Predicate { $0.date == dateStr }
        )
        guard let cached = (try? context.fetch(descriptor))?.first,
              let summary = try? cached.decoded()
        else { return nil }
        return TodayIntentSnapshot(summary: summary)
    }

    // MARK: - UserDefaults routing (for open-app intents)

    public static func setPendingRoute(_ route: String) {
        UserDefaults(suiteName: "group.co.cronx.spark")?
            .set(route, forKey: "spark.pendingRoute")
    }

    // MARK: - Helpers

    private func todayDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }
}

// MARK: - Typed snapshot for intents (avoids AnyCodable in intent code)

public struct TodayIntentSnapshot: Sendable {
    public let sleepScore: Int?
    public let sleepDurationMinutes: Int?
    public let steps: Int?
    public let stepsGoal: Int
    public let spentToday: Double?
    public let currency: String
    public let anomalyCount: Int

    public init(summary: DaySummary) {
        let health = summary.sections.health?.objectValue
        sleepScore = health?["sleep_score"]?.objectValue?["score"]?.intValue
        let durSec = health?["sleep_duration"]?.objectValue?["duration_seconds"]?.intValue
        sleepDurationMinutes = durSec.map { $0 / 60 }

        let activity = summary.sections.activity?.objectValue
        steps = activity?["steps"]?.objectValue?["value"]?.intValue
        stepsGoal = activity?["steps"]?.objectValue?["goal"]?.intValue ?? 10_000

        let money = summary.sections.money?.objectValue
        spentToday = money?["total_spend"]?.doubleValue
        currency = money?["transactions"]?.arrayValue?.first?.objectValue?["currency"]?.stringValue ?? "GBP"

        anomalyCount = summary.anomalies.count
    }

    public var sleepDurationDisplay: String {
        guard let mins = sleepDurationMinutes else { return "unknown duration" }
        let h = mins / 60; let m = mins % 60
        return m == 0 ? "\(h) hours" : "\(h) hours and \(m) minutes"
    }

    public var spentDisplay: String {
        guard let amount = spentToday else { return "nothing" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: abs(amount))) ?? "\(amount)"
    }
}
