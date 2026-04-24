import Foundation
import SwiftData

@Model
public final class CachedDaySummary {
    #Unique<CachedDaySummary>([\.date])

    @Attribute(.unique) public var date: String
    public var timezone: String
    public var payload: Data
    public var lastSyncedAt: Date

    public init(date: String, timezone: String, payload: Data, lastSyncedAt: Date = .init()) {
        self.date = date
        self.timezone = timezone
        self.payload = payload
        self.lastSyncedAt = lastSyncedAt
    }

    public func decoded() throws -> DaySummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DaySummary.self, from: payload)
    }
}
