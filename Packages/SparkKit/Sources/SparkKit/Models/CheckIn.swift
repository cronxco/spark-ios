import Foundation

// MARK: - Period

public enum CheckInPeriod: String, Codable, Sendable, CaseIterable {
    case morning
    case afternoon
}

// MARK: - Submission

public struct CheckInRequest: Encodable, Sendable {
    public let period: CheckInPeriod
    public let physical: Int
    public let mental: Int
    public let date: String
    public let latitude: Double?
    public let longitude: Double?
    public let address: String?
    public let notes: String?

    public init(
        period: CheckInPeriod,
        physical: Int,
        mental: Int,
        date: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        notes: String? = nil
    ) {
        self.period = period
        self.physical = physical
        self.mental = mental
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case period, physical, mental, date, latitude, longitude, address, notes
    }
}

// MARK: - Check-in event (POST response + GET status event field)

/// Subset of the CompactEvent returned by the check-in endpoints.
/// Includes blocks so callers can extract physical/mental scores.
public struct CheckInEvent: Codable, Sendable {
    public let id: String
    public let action: String
    public let value: String?
    public let blocks: [Block]

    enum CodingKeys: String, CodingKey {
        case id, action, value, blocks
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        action = try c.decode(String.self, forKey: .action)
        blocks = try c.decodeIfPresent([Block].self, forKey: .blocks) ?? []
        if let s = try? c.decodeIfPresent(String.self, forKey: .value) {
            value = s
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .value) {
            value = String(i)
        } else {
            value = nil
        }
    }

    public func physical() -> Int? {
        blocks.first(where: { $0.blockType == "physical_energy" })?.value.flatMap { Int($0) }
    }

    public func mental() -> Int? {
        blocks.first(where: { $0.blockType == "mental_energy" })?.value.flatMap { Int($0) }
    }
}

// MARK: - Today status response

public struct CheckInPeriodDetail: Codable, Sendable {
    public let completed: Bool
    public let event: CheckInEvent?
}

public struct CheckInDayResponse: Codable, Sendable {
    public let date: String
    public let morning: CheckInPeriodDetail
    public let afternoon: CheckInPeriodDetail
}

// MARK: - History response

public struct CheckInHistoryPeriod: Codable, Sendable {
    public let completed: Bool
    public let physical: Int?
    public let mental: Int?
    public let combined: Int?
    public let notes: String?
    public let eventId: String?

    public init(completed: Bool, physical: Int? = nil, mental: Int? = nil, combined: Int? = nil, notes: String? = nil, eventId: String? = nil) {
        self.completed = completed
        self.physical = physical
        self.mental = mental
        self.combined = combined
        self.notes = notes
        self.eventId = eventId
    }

    enum CodingKeys: String, CodingKey {
        case completed, physical, mental, combined, notes
        case eventId = "event_id"
    }
}

public struct CheckInHistoryDay: Codable, Sendable {
    public let date: String
    public let morning: CheckInHistoryPeriod
    public let afternoon: CheckInHistoryPeriod

    public init(date: String, morning: CheckInHistoryPeriod, afternoon: CheckInHistoryPeriod) {
        self.date = date
        self.morning = morning
        self.afternoon = afternoon
    }
}

public struct CheckInHistoryResponse: Codable, Sendable {
    public let from: String
    public let to: String
    public let days: [CheckInHistoryDay]
}
