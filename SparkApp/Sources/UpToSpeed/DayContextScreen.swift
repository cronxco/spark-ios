import SparkKit
import SparkUI
import SwiftUI

/// Calendar, birthdays, and weather for today — sourced from the digest's
/// structured `flint_day_context` block rather than scraped out of prose.
struct DayContextScreen: View {
    let dayContext: FlintDayContext
    let yesterday: String?

    var body: some View {
        StoryScreenScaffold {
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                Text("Your day")
                    .font(SparkTypography.hero)
                    .foregroundStyle(.primary)

                if !dayContext.birthdays.isEmpty {
                    birthdayRows
                }

                if !dayContext.calendar.isEmpty {
                    calendarCard
                }

                if dayContext.weather != nil || yesterday != nil {
                    infoGrid
                }
            }
        }
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

    private var calendarCard: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(dayContext.calendar.enumerated()), id: \.element.id) { index, entry in
                    calendarRow(entry)
                    if index < dayContext.calendar.count - 1 {
                        Divider().opacity(0.15)
                    }
                }
            }
        }
    }

    private func calendarRow(_ entry: FlintDayContextEvent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.md) {
            Text(timeText(for: entry))
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 56, alignment: .leading)

            Text(entry.title)
                .font(SparkTypography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: SparkSpacing.sm)

            personTag(entry.person)
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.vertical, SparkSpacing.md)
    }

    private func personTag(_ person: FlintDayContextEvent.Person) -> some View {
        Text(person == .will ? "Will" : "Dan")
            .font(SparkTypography.caption)
            .foregroundStyle(personColor(person))
    }

    private func personColor(_ person: FlintDayContextEvent.Person) -> Color {
        person == .will ? .sparkAccent : .sparkOcean
    }

    private func timeText(for entry: FlintDayContextEvent) -> String {
        if entry.allDay { return "All day" }
        guard let start = entry.start else { return "" }
        return start.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Weather / yesterday

    private var infoGrid: some View {
        HStack(alignment: .top, spacing: SparkSpacing.md) {
            if let weather = dayContext.weather {
                weatherCard(weather)
            }
            if let yesterday {
                yesterdayCard(yesterday)
            }
        }
    }

    private func weatherCard(_ weather: FlintDayContextWeather) -> some View {
        MetricDeltaCard(
            label: "Weather",
            value: weather.tempHighC.map { "\(Int($0.rounded()))°" } ?? "—",
            delta: weatherDelta(weather),
            emphasis: .neutral
        )
    }

    private func weatherDelta(_ weather: FlintDayContextWeather) -> String? {
        let parts = [
            weather.condition,
            weather.rainProbabilityPct.map { "\($0)% rain" },
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func yesterdayCard(_ yesterday: String) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text("YESTERDAY")
                .font(SparkTypography.caption)
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Text(yesterday)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SparkSpacing.lg)
        .sparkGlass(.roundedRect(SparkRadii.lg))
    }
}
