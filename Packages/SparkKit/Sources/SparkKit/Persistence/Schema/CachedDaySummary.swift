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

    /// Payloads are written with a default `JSONEncoder`, so dates are stored
    /// as numbers (seconds since 2001); ones written from the API's own JSON
    /// are ISO 8601 strings. Accept both, or any summary with a date in it
    /// fails to read back and every cache consumer sees no data.
    public func decoded() throws -> DaySummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSinceReferenceDate: seconds)
            }
            let text = try container.decode(String.self)
            let plain = ISO8601DateFormatter()
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = plain.date(from: text) ?? fractional.date(from: text) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognised date \(text)")
        }
        return try decoder.decode(DaySummary.self, from: payload)
    }
}
