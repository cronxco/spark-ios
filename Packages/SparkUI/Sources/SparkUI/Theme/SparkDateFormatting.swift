import Foundation

public enum SparkDateFormatting {
    public static func shortTime(
        _ date: Date,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        var style = Date.FormatStyle()
            .hour()
            .minute()
        style.locale = locale
        style.timeZone = timeZone
        return date.formatted(style)
    }

    public static func shortDate(
        _ date: Date,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        var style = Date.FormatStyle()
            .day()
            .month(.abbreviated)
            .year()
        style.locale = locale
        style.timeZone = timeZone
        return date.formatted(style)
    }

    public static func compactDateTime(
        _ date: Date,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        var style = Date.FormatStyle()
            .day()
            .month(.abbreviated)
            .hour()
            .minute()
        style.locale = locale
        style.timeZone = timeZone
        return date.formatted(style)
    }

    public static func fullDateTime(
        _ date: Date,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        var style = Date.FormatStyle()
            .year()
            .month(.twoDigits)
            .day(.twoDigits)
            .hour()
            .minute()
        style.locale = locale
        style.timeZone = timeZone
        return date.formatted(style)
    }
}
