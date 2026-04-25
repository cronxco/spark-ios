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
        self.health = HealthSnapshot(summary?.sections.health)
        self.activity = ActivitySnapshot(summary?.sections.activity)
        self.money = MoneySnapshot(summary?.sections.money)
        self.media = MediaSnapshot(summary?.sections.media)
        self.knowledge = KnowledgeSnapshot(summary?.sections.knowledge)
        self.anomalies = summary?.anomalies ?? []
        self.heatmapRows = Self.buildHeatmapRows()
        self.checkInStatus = .pending(slot: SparkTimeOfDay.from(date: now))
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE · d MMMM"
        return f
    }()

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
        sleepScore = payload["sleep_score"]?.intValue
        sleepDurationMinutes = payload["sleep_duration_minutes"]?.intValue
        bedtime = payload["bedtime"]?.stringValue
        wakeTime = payload["wake_time"]?.stringValue
        restingHeartRate = payload["resting_heart_rate"]?.intValue
        hrvOvernight = payload["hrv_overnight"]?.intValue
        deepMinutes = payload["deep_minutes"]?.intValue
        remMinutes = payload["rem_minutes"]?.intValue
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
        steps = payload["steps"]?.intValue
        stepsGoal = payload["steps_goal"]?.intValue ?? 10_000
        activeCalories = payload["active_calories"]?.intValue
        activeCaloriesGoal = payload["active_calories_goal"]?.intValue ?? 600
        exerciseMinutes = payload["exercise_minutes"]?.intValue
        exerciseGoal = payload["exercise_goal"]?.intValue ?? 30
        standHours = payload["stand_hours"]?.intValue
        standGoal = payload["stand_goal"]?.intValue ?? 12
        lastWorkout = payload["last_workout"]?.stringValue
    }
}

struct MoneySnapshot {
    struct Transaction: Identifiable {
        let id: String
        let merchant: String
        let amountMinor: Int
        let category: String?
        let time: String?
    }

    let spentTodayMinor: Int?
    let currency: String
    let recent: [Transaction]

    var hasAny: Bool { spentTodayMinor != nil || !recent.isEmpty }

    var spentTodayDisplay: String? {
        guard let spentTodayMinor else { return nil }
        return Self.format(minor: abs(spentTodayMinor), currency: currency)
    }

    static func format(minor: Int, currency: String) -> String {
        let value = Double(minor) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    init?(_ payload: [String: AnyCodable]?) {
        guard let payload, !payload.isEmpty else { return nil }
        spentTodayMinor = payload["spent_today_minor"]?.intValue
        currency = payload["spent_today_currency"]?.stringValue ?? "GBP"
        let array = payload["recent"]?.arrayValue ?? []
        recent = array.enumerated().compactMap { idx, item -> Transaction? in
            guard let obj = item.objectValue,
                  let merchant = obj["merchant"]?.stringValue,
                  let amount = obj["amount_minor"]?.intValue
            else { return nil }
            return Transaction(
                id: "tx_\(idx)_\(merchant)",
                merchant: merchant,
                amountMinor: amount,
                category: obj["category"]?.stringValue,
                time: obj["time"]?.stringValue
            )
        }
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
        bookmarksToday = payload["bookmarks_today"]?.intValue
        newsletterStatus = payload["newsletter_status"]?.stringValue
        if let event = payload["next_calendar_event"]?.objectValue,
           let title = event["title"]?.stringValue,
           let start = event["start"]?.stringValue,
           let end = event["end"]?.stringValue {
            nextCalendarEvent = CalendarEvent(
                title: title,
                start: start,
                end: end,
                location: event["location"]?.stringValue
            )
        } else {
            nextCalendarEvent = nil
        }
    }
}

/// Local-only check-in state for Phase 2. Backend `/check-ins` endpoint
/// lands in a follow-up phase; until then we surface a "pending" prompt and
/// the modal stub.
enum CheckInStatus {
    case pending(slot: SparkTimeOfDay)
    case logged(mood: String, note: String?)
}
