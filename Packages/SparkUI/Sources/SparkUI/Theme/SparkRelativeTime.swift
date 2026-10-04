import Foundation

/// The Spark Design System time rule: relative within a day of now
/// ("22 minutes ago", "in 3 hours"), absolute beyond it — "Tue 14:05" within a
/// week, then "12 Aug", then "12 Aug 2025". Absolute times are set in mono.
public enum SparkRelativeTime {
    public static func string(
        for date: Date,
        relativeTo now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        if !isAbsolute(date, relativeTo: now) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            formatter.locale = locale
            formatter.calendar = calendar
            return formatter.localizedString(for: date, relativeTo: now)
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        if abs(date.timeIntervalSince(now)) < 7 * 24 * 3600 {
            formatter.dateFormat = "EEE HH:mm"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            formatter.dateFormat = "d MMM"
        } else {
            formatter.dateFormat = "d MMM yyyy"
        }
        return formatter.string(from: date)
    }

    /// Whether `string(for:)` renders an absolute time, which callers set in mono.
    public static func isAbsolute(_ date: Date, relativeTo now: Date = .now) -> Bool {
        abs(date.timeIntervalSince(now)) >= 24 * 3600
    }
}
