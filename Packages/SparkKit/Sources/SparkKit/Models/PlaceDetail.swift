import Foundation

/// Richer place payload returned by `/api/v1/mobile/places/{id}`. Wraps the
/// compact `Place` and adds visit history, nearby places, and recent events.
public struct PlaceDetail: Codable, Sendable, Hashable, Identifiable {
    public let place: Place
    public let visitCount: Int
    public let streakDays: Int?
    public let lastVisitedAt: Date?
    public let events: [Event]
    public let nearby: [Place]

    public var id: String { place.id }

    enum CodingKeys: String, CodingKey {
        case place
        case events
        case nearby
        case visitCount = "visit_count"
        case streakDays = "streak_days"
        case lastVisitedAt = "last_visited_at"
    }

    public init(
        place: Place,
        visitCount: Int = 0,
        streakDays: Int? = nil,
        lastVisitedAt: Date? = nil,
        events: [Event] = [],
        nearby: [Place] = []
    ) {
        self.place = place
        self.visitCount = visitCount
        self.streakDays = streakDays
        self.lastVisitedAt = lastVisitedAt
        self.events = events
        self.nearby = nearby
    }
}
