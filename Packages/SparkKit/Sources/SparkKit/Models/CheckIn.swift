import Foundation

public struct CheckIn: Codable, Sendable {
    public let slot: String
    public let mood: String
    public let tags: [String]
    public let note: String?
    public let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case slot, mood, tags, note
        case loggedAt = "logged_at"
    }

    public init(slot: String, mood: String, tags: [String], note: String?, loggedAt: Date = .now) {
        self.slot = slot
        self.mood = mood
        self.tags = tags
        self.note = note
        self.loggedAt = loggedAt
    }
}
