import Foundation

/// The forward-looking `ahead` section `GET /briefing/today` adds for a date
/// after today. It is what the Looking ahead page renders: the day's
/// schedule, plan, weather and, when there is a reason to say it, a bedtime
/// target for tonight.
///
/// Times stay as the server's ISO 8601 strings (in the day's own timezone)
/// and are parsed on read. The day summary is cached by encoding it with a
/// default `JSONEncoder` and decoding it with an ISO 8601 strategy, so a
/// `Date` stored here would not survive the round trip through the cache.
public struct DayAhead: Codable, Sendable, Hashable {
    public let date: String
    /// A plain, factual line about the day, written by the server.
    public let headline: String
    /// The evening digest whose day-context block described this day, when
    /// one has.
    public let digestEventId: String?
    public let weather: FlintDayContextWeather?
    public let firstCommitment: FirstCommitment?
    public let calendar: [CalendarEntry]
    public let birthdays: [FlintDayContextBirthday]
    public let plan: [PlanItem]
    public let dayNoteURL: URL?
    public let sleepTarget: SleepTarget?

    enum CodingKeys: String, CodingKey {
        case date, headline, weather, calendar, birthdays, plan
        case digestEventId = "digest_event_id"
        case firstCommitment = "first_commitment"
        case dayNoteURL = "day_note_url"
        case sleepTarget = "sleep_target"
    }

    public init(
        date: String,
        headline: String,
        digestEventId: String? = nil,
        weather: FlintDayContextWeather? = nil,
        firstCommitment: FirstCommitment? = nil,
        calendar: [CalendarEntry] = [],
        birthdays: [FlintDayContextBirthday] = [],
        plan: [PlanItem] = [],
        dayNoteURL: URL? = nil,
        sleepTarget: SleepTarget? = nil
    ) {
        self.date = date
        self.headline = headline
        self.digestEventId = digestEventId
        self.weather = weather
        self.firstCommitment = firstCommitment
        self.calendar = calendar
        self.birthdays = birthdays
        self.plan = plan
        self.dayNoteURL = dayNoteURL
        self.sleepTarget = sleepTarget
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        headline = try c.decodeIfPresent(String.self, forKey: .headline) ?? ""
        digestEventId = try c.decodeIfPresent(String.self, forKey: .digestEventId)
        weather = try c.decodeIfPresent(FlintDayContextWeather.self, forKey: .weather)
        firstCommitment = try c.decodeIfPresent(FirstCommitment.self, forKey: .firstCommitment)
        calendar = try c.decodeIfPresent([CalendarEntry].self, forKey: .calendar) ?? []
        birthdays = try c.decodeIfPresent([FlintDayContextBirthday].self, forKey: .birthdays) ?? []
        plan = try c.decodeIfPresent([PlanItem].self, forKey: .plan) ?? []
        // A malformed link costs the "Open day note" button, not the page.
        dayNoteURL = (try? c.decodeIfPresent(String.self, forKey: .dayNoteURL)).flatMap { URL(string: $0) }
        sleepTarget = try c.decodeIfPresent(SleepTarget.self, forKey: .sleepTarget)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(headline, forKey: .headline)
        try c.encodeIfPresent(digestEventId, forKey: .digestEventId)
        try c.encodeIfPresent(weather, forKey: .weather)
        try c.encodeIfPresent(firstCommitment, forKey: .firstCommitment)
        try c.encode(calendar, forKey: .calendar)
        try c.encode(birthdays, forKey: .birthdays)
        try c.encode(plan, forKey: .plan)
        try c.encodeIfPresent(dayNoteURL?.absoluteString, forKey: .dayNoteURL)
        try c.encodeIfPresent(sleepTarget, forKey: .sleepTarget)
    }

    /// Whether there is anything about the day to show beyond the headline.
    public var hasSchedule: Bool { !calendar.isEmpty || !birthdays.isEmpty }

    /// Plan items not yet ticked off.
    public var openPlanCount: Int { plan.filter { !$0.done }.count }

    // MARK: - Nested types

    public struct FirstCommitment: Codable, Sendable, Hashable {
        public let title: String
        public let start: String

        public var startDate: Date? { DayAhead.parse(start) }

        public init(title: String, start: String) {
            self.title = title
            self.start = start
        }
    }

    public struct CalendarEntry: Codable, Sendable, Hashable, Identifiable {
        /// Who the commitment belongs to, as the digest attributed it. `nil`
        /// for a synced event no digest has described yet.
        public enum Person: String, Codable, Sendable, Hashable {
            case will, dan, both
        }

        public let title: String
        public let start: String?
        public let end: String?
        public let allDay: Bool
        public let location: String?
        public let person: Person?
        public let eventId: String?

        public var id: String { eventId ?? "\(title)|\(start ?? "all-day")|\(person?.rawValue ?? "")" }
        public var startDate: Date? { start.flatMap(DayAhead.parse) }
        public var endDate: Date? { end.flatMap(DayAhead.parse) }

        enum CodingKeys: String, CodingKey {
            case title, start, end, location, person
            case allDay = "all_day"
            case eventId = "event_id"
        }

        public init(
            title: String,
            start: String? = nil,
            end: String? = nil,
            allDay: Bool = false,
            location: String? = nil,
            person: Person? = nil,
            eventId: String? = nil
        ) {
            self.title = title
            self.start = start
            self.end = end
            self.allDay = allDay
            self.location = location
            self.person = person
            self.eventId = eventId
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try c.decode(String.self, forKey: .title)
            start = try c.decodeIfPresent(String.self, forKey: .start)
            end = try c.decodeIfPresent(String.self, forKey: .end)
            allDay = try c.decodeIfPresent(Bool.self, forKey: .allDay) ?? false
            location = try c.decodeIfPresent(String.self, forKey: .location)
            // An attribution this build does not know shows untagged rather
            // than failing the whole day.
            person = (try? c.decodeIfPresent(String.self, forKey: .person)).flatMap { Person(rawValue: $0) }
            eventId = try c.decodeIfPresent(String.self, forKey: .eventId)
        }
    }

    public struct PlanItem: Codable, Sendable, Hashable, Identifiable {
        public enum Kind: String, Codable, Sendable, Hashable {
            case dayNote = "day_note"
            case topicTask = "topic_task"
            case topicReview = "topic_review"
            case unknown
        }

        public let id: String
        public let title: String
        public let kind: Kind
        public let done: Bool
        public let topicId: String?
        public let topicTitle: String?
        public let url: URL?

        enum CodingKeys: String, CodingKey {
            case id, title, kind, done, url
            case topicId = "topic_id"
            case topicTitle = "topic_title"
        }

        public init(
            id: String,
            title: String,
            kind: Kind,
            done: Bool = false,
            topicId: String? = nil,
            topicTitle: String? = nil,
            url: URL? = nil
        ) {
            self.id = id
            self.title = title
            self.kind = kind
            self.done = done
            self.topicId = topicId
            self.topicTitle = topicTitle
            self.url = url
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            title = try c.decode(String.self, forKey: .title)
            kind = (try? c.decodeIfPresent(String.self, forKey: .kind)).flatMap { Kind(rawValue: $0) } ?? .unknown
            done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
            topicId = try c.decodeIfPresent(String.self, forKey: .topicId)
            topicTitle = try c.decodeIfPresent(String.self, forKey: .topicTitle)
            url = (try? c.decodeIfPresent(String.self, forKey: .url)).flatMap { URL(string: $0) }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(title, forKey: .title)
            try c.encode(kind, forKey: .kind)
            try c.encode(done, forKey: .done)
            try c.encodeIfPresent(topicId, forKey: .topicId)
            try c.encodeIfPresent(topicTitle, forKey: .topicTitle)
            try c.encodeIfPresent(url?.absoluteString, forKey: .url)
        }
    }

    /// When to be in bed tonight to arrive rested for the first commitment.
    /// The server only sends one when tomorrow starts earlier than usual or
    /// readiness has been low for three nights.
    public struct SleepTarget: Codable, Sendable, Hashable {
        public let wakeBy: String
        public let bedBy: String
        public let sleepNeedMinutes: Int
        /// `HH:mm`, the usual wake time over the last fortnight.
        public let typicalWake: String?
        public let earlyStart: Bool
        public let readinessLowNights: Int

        public var wakeByDate: Date? { DayAhead.parse(wakeBy) }
        public var bedByDate: Date? { DayAhead.parse(bedBy) }

        enum CodingKeys: String, CodingKey {
            case wakeBy = "wake_by"
            case bedBy = "bed_by"
            case sleepNeedMinutes = "sleep_need_minutes"
            case typicalWake = "typical_wake"
            case earlyStart = "early_start"
            case readinessLowNights = "readiness_low_nights"
        }

        public init(
            wakeBy: String,
            bedBy: String,
            sleepNeedMinutes: Int,
            typicalWake: String? = nil,
            earlyStart: Bool = false,
            readinessLowNights: Int = 0
        ) {
            self.wakeBy = wakeBy
            self.bedBy = bedBy
            self.sleepNeedMinutes = sleepNeedMinutes
            self.typicalWake = typicalWake
            self.earlyStart = earlyStart
            self.readinessLowNights = readinessLowNights
        }
    }

    // MARK: - Parsing

    static func parse(_ string: String) -> Date? {
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: string) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: string)
    }
}
