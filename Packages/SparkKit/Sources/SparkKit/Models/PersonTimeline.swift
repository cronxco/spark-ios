import Foundation

/// Payload of `/api/v1/mobile/people/{id}/timeline`: a person's events (acted
/// in, tagged with, or @mentioned) and a month grid of event counts per day.
public struct PersonTimeline: Codable, Sendable, Hashable {
    public let person: EventObject
    public let eventCount: Int
    /// `yyyy-MM`.
    public let month: String
    /// Event count per local day, keyed `yyyy-MM-dd`.
    public let calendar: [String: Int]
    public let events: [Event]

    enum CodingKeys: String, CodingKey {
        case person, month, calendar, events
        case eventCount = "event_count"
    }

    public init(person: EventObject, eventCount: Int, month: String, calendar: [String: Int], events: [Event]) {
        self.person = person
        self.eventCount = eventCount
        self.month = month
        self.calendar = calendar
        self.events = events
    }
}
