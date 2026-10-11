import Foundation

/// When one repeating Flint routine runs, as the backend stores and validates it.
///
/// A schedule holds one or more local `times`, an optional 5-field `cron`, and the
/// `frequency` rules that decide which days `times` apply to. A cron decides its own days.
public struct FlintSchedule: Codable, Sendable, Equatable {
    public var frequency: String?
    public var days: [String]?
    public var dayOfMonth: String?
    public var times: [String]?
    public var cron: String?

    public init(
        frequency: String? = "daily",
        days: [String]? = nil,
        dayOfMonth: String? = nil,
        times: [String]? = nil,
        cron: String? = nil
    ) {
        self.frequency = frequency
        self.days = days
        self.dayOfMonth = dayOfMonth
        self.times = times
        self.cron = cron
    }

    private enum CodingKeys: String, CodingKey {
        case frequency, days, times, cron
        case dayOfMonth = "day_of_month"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frequency = try container.decodeIfPresent(String.self, forKey: .frequency)
        days = try container.decodeIfPresent([String].self, forKey: .days)
        times = try container.decodeIfPresent([String].self, forKey: .times)
        cron = try container.decodeIfPresent(String.self, forKey: .cron)
        // The backend stores 1 to 28 as a number and `last` / `first_working` as text.
        if let text = try? container.decodeIfPresent(String.self, forKey: .dayOfMonth) {
            dayOfMonth = text
        } else if let number = try? container.decodeIfPresent(Int.self, forKey: .dayOfMonth) {
            dayOfMonth = String(number)
        } else {
            dayOfMonth = nil
        }
    }
}

/// One routine in the schedule editor: whether it is on, its schedule and when it runs next.
public struct FlintRoutineSchedule: Decodable, Sendable, Equatable, Identifiable {
    public let routine: String
    public let enabled: Bool
    public let schedule: FlintSchedule?
    public let defaultTime: String
    public let nextRun: Date?

    public var id: String { routine }

    public var displayName: String {
        switch routine {
        case "topics": "Topic review"
        case "reading_list": "Reading list"
        case "news_roundup": "News roundup"
        case "money_weekly": "Money weekly check"
        case "money_close": "Money monthly close"
        default: routine.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private enum CodingKeys: String, CodingKey {
        case routine, enabled, schedule
        case defaultTime = "default_time"
        case nextRun = "next_run"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        routine = try container.decode(String.self, forKey: .routine)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        schedule = try container.decodeIfPresent(FlintSchedule.self, forKey: .schedule)
        defaultTime = try container.decode(String.self, forKey: .defaultTime)
        if let text = try container.decodeIfPresent(String.self, forKey: .nextRun) {
            nextRun = ISO8601DateFormatter().date(from: text)
        } else {
            nextRun = nil
        }
    }
}

/// `GET /flint/schedules` wraps the list in `data`; `PUT` wraps one routine in `data`.
public struct FlintSchedulesResponse: Decodable, Sendable {
    public let routines: [FlintRoutineSchedule]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        routines = try container.decode([FlintRoutineSchedule].self, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey { case data }
}

public struct FlintRoutineScheduleResponse: Decodable, Sendable {
    public let routine: FlintRoutineSchedule

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        routine = try container.decode(FlintRoutineSchedule.self, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey { case data }
}
