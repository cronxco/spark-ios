import Foundation
import SparkKit
import SparkUI


/// Fully typed projection of `DaySummary` for Today rendering. Each domain
/// is optional; cards opt out when their snapshot is `nil` or empty.
///
/// We keep `DaySummary.sections` as `[String: AnyCodable]` upstream so the
/// API contract stays loose, and decode into these typed views at the
/// presentation layer.
struct TodaySnapshot {
    let date: Date
    let timeOfDay: SparkTimeOfDay
    let dateLabel: String
    let health: HealthSnapshot?
    let activity: ActivitySnapshot?
    let money: MoneySnapshot?
    let media: MediaSnapshot?
    let knowledge: KnowledgeSnapshot?
    let anomalies: [Anomaly]
    let heatmapRows: [DomainHeatmapRow]
    let checkInStatus: CheckInStatus

    init(summary: DaySummary?, date: Date, now: Date = .now) {
        self.date = date
        self.timeOfDay = SparkTimeOfDay.from(date: now)
        self.dateLabel = Self.dateFormatter.string(from: date)
        self.health = HealthSnapshot(summary?.sections.health?.objectValue)
        self.activity = ActivitySnapshot(summary?.sections.activity?.objectValue)
        self.money = MoneySnapshot(summary?.sections.money?.objectValue)
        self.media = MediaSnapshot(summary?.sections.media?.objectValue)
        self.knowledge = KnowledgeSnapshot(summary?.sections.knowledge?.objectValue)
        self.anomalies = summary?.anomalies ?? []
        self.heatmapRows = Self.buildHeatmapRows()
        let slot = SparkTimeOfDay.from(date: now)
        self.checkInStatus = Self.loadCheckIn(date: date, slot: slot)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE · d MMMM"
        return f
    }()

    private static func loadCheckIn(date: Date, slot: SparkTimeOfDay) -> CheckInStatus {
        let dateKey = isoDate(date)
        let key = "checkin_\(dateKey)_\(slot.rawValue)"
        guard let data = UserDefaults(suiteName: "group.co.cronx.spark")?.data(forKey: key) else {
            return .pending(slot: slot)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let entry = try? decoder.decode(CheckIn.self, from: data) else {
            return .pending(slot: slot)
        }
        return .logged(mood: entry.mood, note: entry.note)
    }

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func buildHeatmapRows() -> [DomainHeatmapRow] {
        // Backend `/api/v1/mobile/heatmap` doesn't exist yet — Phase 2 ships a
        // deterministic placeholder so the UX lands now and we swap data
        // when the endpoint goes live.
        let raw = HeatmapPlaceholder.generate()
        return [
            .init(id: "sleep", label: "Sleep", values: raw["sleep"] ?? [], tint: .domainHealth),
            .init(id: "motion", label: "Motion", values: raw["activity"] ?? [], tint: .domainActivity),
            .init(id: "spend", label: "Spend", values: raw["spend"] ?? [], tint: .domainMoney),
            .init(id: "mood", label: "Mood", values: raw["mood"] ?? [], tint: .sparkSuccess),
        ]
    }
}

// MARK: - Domain snapshots

struct HealthSnapshot {
    let sleepScore: Int?
    let sleepDurationMinutes: Int?
    let bedtime: String?
    let wakeTime: String?
    let restingHeartRate: Int?
    let hrvOvernight: Int?
    let deepMinutes: Int?
    let remMinutes: Int?

    var hasSleep: Bool { sleepScore != nil || sleepDurationMinutes != nil }

    init?(_ payload: [String: AnyCodable]?) {
        guard let payload, !payload.isEmpty else { return nil }
        sleepScore = payload["sleep_score"]?.objectValue?["score"]?.intValue
        let durSec = payload["sleep_duration"]?.objectValue?["duration_seconds"]?.intValue
        sleepDurationMinutes = durSec.map { $0 / 60 }
        bedtime = nil
        wakeTime = nil
        restingHeartRate = nil
        hrvOvernight = payload["hrv"]?.objectValue?["value"]?.intValue
        let stages = payload["sleep_duration"]?.objectValue?["stages"]?.objectValue
        deepMinutes = stages?["Deep Sleep Duration"]?.doubleValue.map { Int($0) / 60 }
        remMinutes = stages?["REM Sleep Duration"]?.doubleValue.map { Int($0) / 60 }
    }
}

struct ActivitySnapshot {
    let steps: Int?
    let stepsGoal: Int
    let activeCalories: Int?
    let activeCaloriesGoal: Int
    let exerciseMinutes: Int?
    let exerciseGoal: Int
    let standHours: Int?
    let standGoal: Int
    let lastWorkout: String?

    var hasAny: Bool {
        steps != nil || activeCalories != nil || exerciseMinutes != nil || standHours != nil
    }

    var moveProgress: Double {
        guard let activeCalories else { return 0 }
        return Double(activeCalories) / Double(activeCaloriesGoal)
    }

    var exerciseProgress: Double {
        guard let exerciseMinutes else { return 0 }
        return Double(exerciseMinutes) / Double(exerciseGoal)
    }

    var standProgress: Double {
        guard let standHours else { return 0 }
        return Double(standHours) / Double(standGoal)
    }

    init?(_ payload: [String: AnyCodable]?) {
        guard let payload, !payload.isEmpty else { return nil }
        let stepsObj = payload["steps"]?.objectValue
        steps = stepsObj?["value"]?.intValue
        stepsGoal = stepsObj?["goal"]?.intValue ?? 10_000
        let kcalObj = payload["active_energy_kcal"]?.objectValue
        activeCalories = kcalObj?["value"]?.intValue
        activeCaloriesGoal = kcalObj?["goal"]?.intValue ?? 600
        let exObj = payload["exercise_minutes"]?.objectValue
        exerciseMinutes = exObj?["value"]?.intValue
        exerciseGoal = exObj?["goal"]?.intValue ?? 30
        let standObj = payload["stand_hours"]?.objectValue
        standHours = standObj?["value"]?.intValue
        standGoal = standObj?["goal"]?.intValue ?? 12
        lastWorkout = payload["workouts"]?.arrayValue?.first?.objectValue?["name"]?.stringValue
    }
}

struct MoneySnapshot {
    struct Transaction: Identifiable {
        let id: String
        let merchant: String
        let amount: Double
        let currency: String
        let category: String?
        let time: String?
    }

    let spentToday: Double?
    let currency: String
    let recent: [Transaction]

    var hasAny: Bool { spentToday != nil || !recent.isEmpty }

    var spentTodayDisplay: String? {
        guard let spentToday else { return nil }
        return Self.format(amount: abs(spentToday), currency: currency)
    }

    static func format(amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    init?(_ payload: [String: AnyCodable]?) {
        guard let payload, !payload.isEmpty else { return nil }
        spentToday = payload["total_spend"]?.doubleValue
        let array = payload["transactions"]?.arrayValue ?? []
        recent = array.enumerated().compactMap { idx, item -> Transaction? in
            guard let obj = item.objectValue,
                  let merchant = obj["merchant"]?.stringValue,
                  let amount = obj["amount"]?.doubleValue
            else { return nil }
            let txId = obj["id"]?.stringValue ?? "tx_\(idx)_\(merchant)"
            return Transaction(
                id: txId,
                merchant: merchant,
                amount: amount,
                currency: obj["currency"]?.stringValue ?? "GBP",
                category: obj["category"]?.stringValue,
                time: obj["time"]?.stringValue
            )
        }
        currency = recent.first?.currency ?? "GBP"
    }
}

struct MediaSnapshot {
    let spotifyMinutes: Int?
    let topTrack: String?
    let topArtist: String?
    let lastSongAt: String?
    let untappdToday: String?

    var hasAny: Bool { topTrack != nil || spotifyMinutes != nil || untappdToday != nil }

    init?(_ payload: [String: AnyCodable]?) {
        guard let payload, !payload.isEmpty else { return nil }
        spotifyMinutes = payload["spotify_minutes"]?.intValue
        topTrack = payload["top_track"]?.stringValue
        topArtist = payload["top_artist"]?.stringValue
        lastSongAt = payload["last_song_at"]?.stringValue
        untappdToday = payload["untappd_today"]?.stringValue
    }
}

struct KnowledgeSnapshot {
    struct CalendarEvent {
        let title: String
        let start: String
        let end: String
        let location: String?
    }

    let bookmarksToday: Int?
    let newsletterStatus: String?
    let nextCalendarEvent: CalendarEvent?

    var hasAny: Bool { nextCalendarEvent != nil || (bookmarksToday ?? 0) > 0 }

    init?(_ payload: [String: AnyCodable]?) {
        guard let payload, !payload.isEmpty else { return nil }
        let bookmarkArray = payload["bookmarks"]?.arrayValue
        bookmarksToday = bookmarkArray.map { $0.count }
        let newsletterArray = payload["newsletters"]?.arrayValue ?? []
        newsletterStatus = newsletterArray.isEmpty ? nil : "\(newsletterArray.count) newsletters"
        nextCalendarEvent = nil
    }
}

/// Local-only check-in state for Phase 2. Backend `/check-ins` endpoint
/// lands in a follow-up phase; until then we surface a "pending" prompt and
/// the modal stub.
enum CheckInStatus {
    case pending(slot: SparkTimeOfDay)
    case logged(mood: String, note: String?)
}
