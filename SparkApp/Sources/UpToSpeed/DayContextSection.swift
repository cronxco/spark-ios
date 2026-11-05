import SparkKit
import SparkUI
import SwiftUI

/// Calendar, birthdays and weather for the day the digest describes — sourced
/// from its structured `flint_day_context` block rather than scraped out of
/// prose.
///
/// This used to be a chapter of its own, several swipes into the flow, while
/// the opener led with paragraphs lifted off the digest. It is a section now,
/// rendered directly on the opener: the day is what the reader opens Up to
/// Speed for, and it should not be behind anything.
struct DayContextSection: View {
    let dayContext: FlintDayContext
    let yesterday: String?
    var now: Date = .now
    @State private var showsFullDay = false

    /// All-day entries first, then timed ones in order. Collapsed, the card
    /// keeps every all-day entry (they were a loose grey line under the card
    /// before, while the expanded card drew them as rows) and the next
    /// three timed entries still ahead.
    private var calendarEntries: [FlintDayContextEvent] {
        let sorted = dayContext.calendar.sorted { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }
        let allDay = sorted.filter(\.allDay)
        let timed = sorted.filter { !$0.allDay }
        guard !showsFullDay else { return allDay + timed }
        return allDay + Array(timed.filter { ($0.start ?? .distantPast) > now }.prefix(3))
    }

    private var hasHiddenEntries: Bool {
        calendarEntries.count < dayContext.calendar.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.lg) {
            Text(dayLabel).font(SparkTypography.bodyStrong)

            if let weather = dayContext.weather, weather.hasContent {
                weatherRow(weather)
            }

            if !dayContext.birthdays.isEmpty {
                birthdayRows
            }

            if !calendarEntries.isEmpty {
                calendarCard
            }

            // A link in the accent role (§3.1), and only when it would
            // change something.
            if showsFullDay || hasHiddenEntries {
                Button(showsFullDay ? "Show fewer" : "Show all events") { showsFullDay.toggle() }
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(Color.sparkLink)
                    .frame(minHeight: 44)
            }

            if let yesterday {
                yesterdayBlock(yesterday)
            }
        }
    }

    // MARK: - Day label

    /// "Today", "Tomorrow", or the weekday for anything further out. A digest
    /// that names no day is describing the day it was written on.
    private var dayLabel: String {
        let calendar = Calendar.current
        // Resolved in the same calendar it is compared against, so a bare
        // yyyy-MM-dd cannot land on the wrong side of local midnight.
        guard let day = dayContext.day(in: calendar) else { return "Today" }

        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(day, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        if let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(day, inSameDayAs: yesterdayDate) {
            return "Yesterday"
        }
        return day.formatted(.dateTime.weekday(.wide))
    }

    // MARK: - Birthdays

    private var birthdayRows: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            ForEach(dayContext.birthdays) { birthday in
                HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                    SparkGlyph(.birthday, relativeTo: .headline)
                    Text(birthday.title)
                }
                .font(SparkTypography.bodyStrong)
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Calendar

    /// The first timed entry still ahead — given a little weight so a day with
    /// eight rows still says which one is next.
    private var nextEntryID: String? {
        calendarEntries
            .first { entry in
                guard !entry.allDay, let start = entry.start else { return false }
                return start > now
            }?
            .id
    }

    private var calendarCard: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(calendarEntries.enumerated()), id: \.element.id) { index, entry in
                    calendarRow(entry)
                    if index < calendarEntries.count - 1 {
                        Divider().opacity(0.15)
                    }
                }
            }
        }
    }

    /// Time, title, and who it belongs to. The time column is exactly as
    /// wide as "00:00", so a short time no longer leaves a hole before the
    /// title. Your own entries need no marker; Dan's say "Dan" in words
    /// rather than by the colour of a dot.
    private func calendarRow(_ entry: FlintDayContextEvent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.md) {
            timeLabel(for: entry)

            Text(entry.title)
                .font(entry.id == nextEntryID ? SparkTypography.bodyStrong : SparkTypography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Metadata spaced by a gap, never a divider (§9).
            HStack(spacing: SparkSpacing.md) {
                if entry.allDay {
                    Text("All day")
                }
                if entry.person != .will {
                    Text(personName(entry.person))
                }
            }
            .font(SparkTypography.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.vertical, SparkSpacing.md)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibleLabel(for: entry))
    }

    /// A time column that only ever holds times, sized to "00:00". An
    /// all-day entry leaves it empty and says "All day" at the end of the
    /// row instead, so the column still reads as a schedule.
    private func timeLabel(for entry: FlintDayContextEvent) -> some View {
        Text("00:00")
            .font(SparkTypography.caption)
            .monospacedDigit()
            .hidden()
            .overlay(alignment: .leading) {
                Text(entry.allDay ? "" : Self.clockTime(entry.start))
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize()
            }
    }

    /// Exact times are always 24-hour, "08:10" (§12.2), whatever the
    /// device's locale.
    static func clockTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
                timeZone: .current,
                calendar: .current
            )
        )
    }

    private func personName(_ person: FlintDayContextEvent.Person) -> String {
        person == .will ? "Will" : "Dan"
    }

    private func accessibleLabel(for entry: FlintDayContextEvent) -> String {
        let owner = entry.person == .will ? nil : personName(entry.person)
        return [entry.title, accessibleTime(for: entry), owner].compactMap { $0 }.joined(separator: ", ")
    }

    private func accessibleTime(for entry: FlintDayContextEvent) -> String {
        if entry.allDay { return "all day" }
        guard let start = entry.start else { return "time unknown" }
        return start.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Weather

    /// A weather line, not a metric tile. This was a `MetricDeltaCard` borrowed
    /// from the anomaly screen's readout grid, which is why it read as a
    /// statistic about the weather rather than the weather.
    private func weatherRow(_ weather: FlintDayContextWeather) -> some View {
        HStack(spacing: SparkSpacing.md) {
            // A Font Awesome glyph from the manifest (§6), neutral: weather
            // has no domain, so its colour would only be decoration.
            SparkGlyph(Self.glyph(for: weather.condition, rainProbability: weather.rainProbabilityPct), size: 26, relativeTo: .title2)
                .foregroundStyle(.primary)
                .frame(width: 34)

            // Temperature over the condition, so a long condition gets the
            // card's full width instead of wrapping in a column beside it.
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    if let temp = weather.tempHighC {
                        Text("High \(Int(temp.rounded()))°")
                            .font(SparkFonts.display(.title2, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    Spacer(minLength: SparkSpacing.sm)
                    // On a travel weekend the location is the part of this
                    // card that tells you something.
                    if let location = weather.location, !location.isEmpty {
                        Text(location)
                            .font(SparkTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let detail = weatherDetail(weather) {
                    Text(detail)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(SparkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Content, so the opaque surface; glass is for controls (§5.3).
        .sparkContentSurface(radius: SparkRadii.lg)
        .accessibilityElement(children: .combine)
    }

    private func weatherDetail(_ weather: FlintDayContextWeather) -> String? {
        let parts = [
            weather.condition,
            // "0% rain" beside "drizzle possible" contradicts itself.
            weather.rainProbabilityPct.flatMap { $0 > 0 ? "\($0)% rain" : nil },
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    static func glyph(for condition: String?, rainProbability: Int? = nil) -> SparkIcon {
        guard let condition = condition?.lowercased() else { return .weatherCloudy }
        // A forecast of no rain shouldn't draw rain, whatever the wording.
        let rainless = rainProbability == 0

        if condition.contains("thunder") { return .weatherStorm }
        if condition.contains("snow") || condition.contains("sleet") { return .weatherSnow }
        if condition.contains("drizzle") || condition.contains("rain") || condition.contains("shower") {
            return rainless ? .weatherCloudy : .weatherRain
        }
        if condition.contains("fog") || condition.contains("mist") { return .weatherFog }
        if condition.contains("wind") || condition.contains("breez") { return .weatherWind }
        // Checked before the bare "cloud" test, which would otherwise swallow it.
        if condition.contains("part"), condition.contains("cloud") { return .weatherPartlyCloudy }
        if condition.contains("overcast") || condition.contains("cloud") { return .weatherCloudy }
        if condition.contains("clear") || condition.contains("sun") || condition.contains("fair") {
            return .weatherClear
        }
        return .weatherCloudy
    }

    /// SF Symbol twin of `glyph(for:)`, for the Looking Ahead chips, which
    /// have not moved onto the manifest yet.
    static func symbol(for condition: String?, rainProbability: Int? = nil) -> String {
        guard let condition = condition?.lowercased() else { return "cloud.fill" }
        // A forecast of no rain shouldn't draw rain, whatever the wording.
        let rainless = rainProbability == 0

        if condition.contains("thunder") { return "cloud.bolt.rain.fill" }
        if condition.contains("snow") || condition.contains("sleet") { return "cloud.snow.fill" }
        if condition.contains("drizzle") { return rainless ? "cloud.fill" : "cloud.drizzle.fill" }
        if condition.contains("rain") || condition.contains("shower") { return rainless ? "cloud.fill" : "cloud.rain.fill" }
        if condition.contains("fog") || condition.contains("mist") { return "cloud.fog.fill" }
        if condition.contains("wind") || condition.contains("breez") { return "wind" }
        // Checked before the bare "cloud" test, which would otherwise swallow it.
        if condition.contains("part"), condition.contains("cloud") { return "cloud.sun.fill" }
        if condition.contains("overcast") || condition.contains("cloud") { return "cloud.fill" }
        if condition.contains("clear") || condition.contains("sun") || condition.contains("fair") {
            return "sun.max.fill"
        }
        return "cloud.fill"
    }

    // MARK: - Yesterday

    /// Full width and below the day, rather than squeezed into an `HStack`
    /// beside the weather where neither had room.
    private func yesterdayBlock(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text("Yesterday")
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
            // Flint writes markdown: bold labels and links to Spark records.
            SparkRichContentText(text: text, font: SparkTypography.bodySmall, lineSpacing: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SparkSpacing.lg)
        .sparkContentSurface(radius: SparkRadii.lg)
    }
}
