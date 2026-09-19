import SwiftUI

/// The four time-of-day slots the app background is drawn from. The clock
/// picks the slot; the colour scheme decides how it is drawn. See
/// `SparkAppBackground`.
public enum SparkTimeOfDay: String, CaseIterable, Sendable {
    case morning
    case day
    case evening
    case night

    /// Pick the slot for the given hour of day (24h, local time).
    public static func from(hour: Int) -> SparkTimeOfDay {
        switch hour {
        case 5..<11: .morning
        case 11..<17: .day
        case 17..<21: .evening
        default: .night
        }
    }

    public static func from(date: Date, calendar: Calendar = .current) -> SparkTimeOfDay {
        from(hour: calendar.component(.hour, from: date))
    }

    /// Default greeting copy. Callers can override.
    public var greeting: String {
        switch self {
        case .morning: "Good morning"
        case .day: "Good afternoon"
        case .evening: "Good evening"
        case .night: "Still up?"
        }
    }
}
