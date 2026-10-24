import Foundation

/// Reads when something happened from the words the user used: "yesterday at 8pm", "last night", "Saturday lunch", "40 minutes ago".
/// Returns nil when the words say nothing about time, so the entry is logged as happening now.
enum LogWhenParser {
    private static let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    private static let partsOfDay: [(word: String, hour: Int, evening: Bool)] = [
        ("breakfast", 8, false),
        ("morning", 9, false),
        ("afternoon", 15, false),
        ("midday", 12, false),
        ("noon", 12, false),
        ("lunch", 13, false),
        ("evening", 19, true),
        ("dinner", 19, true),
        ("night", 21, true),
    ]

    private struct Clock {
        var hour: Int
        var minute: Int
        /// An hour said without am or pm, such as "at 8".
        var needsMeridiem: Bool
    }

    static func date(from phrase: String, now: Date, calendar: Calendar = .current) -> Date? {
        let text = phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let earlier = timeAgo(in: text, now: now, calendar: calendar) { return earlier }

        let offset = dayOffset(in: text, now: now, calendar: calendar)
        let part = partsOfDay.first { text.contains($0.word) }
        guard var clock = spokenClock(in: text) ?? part.map({ Clock(hour: $0.hour, minute: 0, needsMeridiem: false) }) else {
            guard let offset, offset != 0, let noon = atTime(hour: 12, minute: 0, dayOffset: offset, now: now, calendar: calendar) else {
                return nil
            }
            return min(noon, now)
        }

        if clock.needsMeridiem, clock.hour < 12, part?.evening == true {
            clock.hour += 12
            clock.needsMeridiem = false
        } else if clock.needsMeridiem, text.contains("morning") {
            clock.needsMeridiem = false
        }

        let hours = clock.needsMeridiem && clock.hour < 12 ? [clock.hour, clock.hour + 12] : [clock.hour]
        var candidates = hours.compactMap {
            atTime(hour: $0, minute: clock.minute, dayOffset: offset ?? 0, now: now, calendar: calendar)
        }
        guard !candidates.isEmpty else { return nil }

        if let latestPast = candidates.filter({ $0 <= now }).max() {
            return latestPast
        }

        if offset == nil {
            candidates = candidates.compactMap { calendar.date(byAdding: .day, value: -1, to: $0) }
            return candidates.max()
        }
        return min(candidates.min() ?? now, now)
    }

    private static func timeAgo(in text: String, now: Date, calendar: Calendar) -> Date? {
        guard let match = text.firstMatch(of: #/(\d+|an?|half an?)\s*(minutes?|mins?|hours?|hrs?|days?)\s+ago/#) else {
            return nil
        }

        let amount = String(match.1)
        let unit = String(match.2)
        let count: Double
        if amount.hasPrefix("half") {
            count = 0.5
        } else {
            count = Double(amount) ?? 1
        }

        let seconds: Double
        switch unit.first {
        case "m": seconds = 60
        case "h": seconds = 3_600
        default: seconds = 86_400
        }
        return now.addingTimeInterval(-count * seconds)
    }

    private static func dayOffset(in text: String, now: Date, calendar: Calendar) -> Int? {
        if text.contains("day before yesterday") { return -2 }
        if text.contains("yesterday") || text.contains("last night") { return -1 }
        if text.contains("today") || text.contains("tonight") || text.contains("this ") { return 0 }

        guard let target = weekdays.firstIndex(where: { text.contains($0) }) else { return nil }
        let today = calendar.component(.weekday, from: now) - 1
        var difference = (today - target + 7) % 7
        if difference == 0, text.contains("last") { difference = 7 }
        return -difference
    }

    private static func spokenClock(in text: String) -> Clock? {
        if let match = text.firstMatch(of: #/(\d{1,2})(?::(\d{2}))?\s*(am|pm)/#) {
            guard var hour = Int(match.1), (1...12).contains(hour) else { return nil }
            let minute = match.2.flatMap { Int($0) } ?? 0
            guard (0...59).contains(minute) else { return nil }
            hour = hour % 12 + (match.3 == "pm" ? 12 : 0)
            return Clock(hour: hour, minute: minute, needsMeridiem: false)
        }

        if let match = text.firstMatch(of: #/(\d{1,2}):(\d{2})/#) {
            guard let hour = Int(match.1), let minute = Int(match.2), (0...23).contains(hour), (0...59).contains(minute) else {
                return nil
            }
            return Clock(hour: hour, minute: minute, needsMeridiem: (1...11).contains(hour))
        }

        if let match = text.firstMatch(of: #/\bat (\d{1,2})\b/#) {
            guard let hour = Int(match.1), (1...12).contains(hour) else { return nil }
            return Clock(hour: hour % 12 == 0 ? 12 : hour, minute: 0, needsMeridiem: hour < 12)
        }

        return nil
    }

    private static func atTime(hour: Int, minute: Int, dayOffset: Int, now: Date, calendar: Calendar) -> Date? {
        guard
            let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
            let result = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        else { return nil }
        return result
    }
}
