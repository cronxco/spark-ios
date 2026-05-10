import Foundation
import SwiftData

@Model
public final class CachedCheckIn {
    @Attribute(.unique) public var compositeKey: String  // "\(date)_\(period)"
    public var date: String           // YYYY-MM-DD
    public var period: String         // "morning" | "afternoon"
    public var completed: Bool
    public var physical: Int?
    public var mental: Int?
    public var notes: String?
    public var eventId: String?
    public var lastSyncedAt: Date

    public init(
        date: String,
        period: String,
        completed: Bool,
        physical: Int? = nil,
        mental: Int? = nil,
        notes: String? = nil,
        eventId: String? = nil,
        lastSyncedAt: Date = .now
    ) {
        self.compositeKey = "\(date)_\(period)"
        self.date = date
        self.period = period
        self.completed = completed
        self.physical = physical
        self.mental = mental
        self.notes = notes
        self.eventId = eventId
        self.lastSyncedAt = lastSyncedAt
    }

    public static func upsert(
        date: String,
        period: CheckInPeriod,
        completed: Bool,
        physical: Int? = nil,
        mental: Int? = nil,
        notes: String? = nil,
        eventId: String? = nil,
        in context: ModelContext
    ) {
        let key = "\(date)_\(period.rawValue)"
        let descriptor = FetchDescriptor<CachedCheckIn>(
            predicate: #Predicate { $0.compositeKey == key }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.completed = completed
            existing.physical = physical
            existing.mental = mental
            existing.notes = notes
            existing.eventId = eventId
            existing.lastSyncedAt = .now
        } else {
            context.insert(CachedCheckIn(
                date: date,
                period: period.rawValue,
                completed: completed,
                physical: physical,
                mental: mental,
                notes: notes,
                eventId: eventId
            ))
        }
    }
}
