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

    private var calendarEntries: [FlintDayContextEvent] { dayContext.calendar }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.lg) {
            SectionLabel(dayLabel)

            if !dayContext.birthdays.isEmpty {
                birthdayRows
            }

            if !calendarEntries.isEmpty {
                calendarCard
            }

            if let weather = dayContext.weather, weather.hasContent {
                weatherRow(weather)
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
                Label(birthday.title, systemImage: "birthday.cake.fill")
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

    private func calendarRow(_ entry: FlintDayContextEvent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.md) {
            timeLabel(for: entry)

            Text(entry.title)
                .font(entry.id == nextEntryID ? SparkTypography.bodyStrong : SparkTypography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, SparkSpacing.lg)
        .padding(.trailing, SparkSpacing.lg)
        .padding(.vertical, SparkSpacing.md)
        // Whose commitment it is, as a colour down the edge rather than a name
        // in the corner — the name was competing with the title for attention.
        // An overlay rather than a stacked child so the rule takes the row's
        // full height without depending on how the baseline resolves.
        .overlay(alignment: .leading) {
            Capsule()
                .fill(personColor(entry.person))
                .frame(width: 3)
                .padding(.vertical, SparkSpacing.xs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(personName(entry.person)): \(entry.title), \(accessibleTime(for: entry))")
    }

    /// All-day entries get a chip, not a fake time — the time column should
    /// only ever hold times, so a glance down it reads as a schedule.
    @ViewBuilder
    private func timeLabel(for entry: FlintDayContextEvent) -> some View {
        if entry.allDay {
            Text("All day")
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, SparkSpacing.sm)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
                .frame(width: 62, alignment: .leading)
        } else {
            Text(entry.start?.formatted(date: .omitted, time: .shortened) ?? "—")
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 62, alignment: .leading)
        }
    }

    private func personName(_ person: FlintDayContextEvent.Person) -> String {
        person == .will ? "Will" : "Dan"
    }

    private func personColor(_ person: FlintDayContextEvent.Person) -> Color {
        person == .will ? .sparkAccent : .sparkOcean
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
            Image(systemName: Self.symbol(for: weather.condition))
                .font(.system(size: 26))
                .foregroundStyle(Color.sparkOcean)
                .frame(width: 34)

            if let temp = weather.tempHighC {
                Text("\(Int(temp.rounded()))°")
                    .font(SparkFonts.display(.title2, weight: .bold))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 1) {
                if let detail = weatherDetail(weather) {
                    Text(detail)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
                // Decoded all along and never shown. On a travel weekend the
                // location is the half of this line that tells you something.
                if let location = weather.location, !location.isEmpty {
                    Text(location)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(SparkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGlass(.roundedRect(SparkRadii.lg))
        .accessibilityElement(children: .combine)
    }

    private func weatherDetail(_ weather: FlintDayContextWeather) -> String? {
        let parts = [
            weather.condition,
            weather.rainProbabilityPct.map { "\($0)% rain" },
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func symbol(for condition: String?) -> String {
        guard let condition = condition?.lowercased() else { return "cloud.fill" }

        if condition.contains("thunder") { return "cloud.bolt.rain.fill" }
        if condition.contains("snow") || condition.contains("sleet") { return "cloud.snow.fill" }
        if condition.contains("drizzle") { return "cloud.drizzle.fill" }
        if condition.contains("rain") || condition.contains("shower") { return "cloud.rain.fill" }
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
            Text("YESTERDAY")
                .font(SparkTypography.caption)
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Text(text)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SparkSpacing.lg)
        .sparkGlass(.roundedRect(SparkRadii.lg))
    }
}
