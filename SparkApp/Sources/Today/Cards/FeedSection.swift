import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct FeedSection: View {
    let date: Date
    @Query private var allEvents: [CachedEvent]

    private var dayEvents: [CachedEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return allEvents
            .filter { e in
                guard let t = e.time else { return false }
                return t >= start && t < end
            }
            .sorted { ($0.time ?? .distantPast) > ($1.time ?? .distantPast) }
    }

    private var hourGroups: [(hour: Int, events: [CachedEvent])] {
        var grouped: [Int: [CachedEvent]] = [:]
        for event in dayEvents {
            guard let t = event.time else { continue }
            let h = Calendar.current.component(.hour, from: t)
            grouped[h, default: []].append(event)
        }
        return grouped.keys.sorted(by: >).map { h in (hour: h, events: grouped[h]!) }
    }

    var body: some View {
        if !dayEvents.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                HStack(alignment: .center, spacing: SparkSpacing.sm) {
                    Text("Timeline")
                        .font(SparkFonts.display(.title2, weight: .bold))
                    Spacer(minLength: SparkSpacing.sm)
                    filterPill("All", isSelected: true)
                    filterPill("£", systemImage: nil)
                    filterPill(nil, systemImage: "heart.fill")
                    filterPill(nil, systemImage: "books.vertical.fill")
                }

                ForEach(hourGroups, id: \.hour) { group in
                    HourGroup(hour: group.hour, events: group.events)
                }
            }
        }
    }

    private func filterPill(_ text: String?, systemImage: String? = nil, isSelected: Bool = false) -> some View {
        HStack(spacing: SparkSpacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            if let text {
                Text(text)
            }
        }
        .font(SparkTypography.captionStrong)
        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        .frame(minWidth: 38, minHeight: 38)
        .padding(.horizontal, text == nil ? 0 : SparkSpacing.sm)
        .background(.regularMaterial, in: .circle)
        .overlay {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

// MARK: - Hour group

private struct HourGroup: View {
    let hour: Int
    let events: [CachedEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack(spacing: SparkSpacing.md) {
                Text(String(format: "%02d:00", hour))
                    .font(SparkFonts.mono(.title3))
                    .foregroundStyle(Color.secondary.opacity(0.68))
                    .monospacedDigit()
                    .frame(width: 72, alignment: .leading)

                Rectangle()
                    .fill(Color.primary.opacity(0.09))
                    .frame(height: 1)
            }

            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                ForEach(events) { event in
                    NavigationLink(value: DetailRoute.event(id: event.id)) {
                        row(for: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for event: CachedEvent) -> some View {
        if isWebDigest(event) {
            WebDigestEventCard(event: event)
        } else if isStandout(event) {
            StandoutEventCard(event: event)
        } else if isSubtle(event) {
            SubtleEventRow(event: event)
        } else {
            RaisedEventCard(event: event)
        }
    }

    private func isWebDigest(_ event: CachedEvent) -> Bool {
        event.domain == "knowledge" && (event.service == "fetch" || event.value?.lowercased().contains("web") == true)
    }

    private func isStandout(_ event: CachedEvent) -> Bool {
        guard event.domain == "money",
              let value = event.value,
              let amount = Double(value.replacingOccurrences(of: ",", with: ""))
        else { return false }
        return abs(amount) >= 100
    }

    private func isSubtle(_ event: CachedEvent) -> Bool {
        event.value == nil || event.action.lowercased().contains("transfer")
    }
}

// MARK: - Raised event card

private struct RaisedEventCard: View {
    let event: CachedEvent

    var body: some View {
        HStack(alignment: .center, spacing: SparkSpacing.md) {
            iconBox

            VStack(alignment: .leading, spacing: 2) {
                Text(metaLine(for: event))
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(Color.secondary.opacity(0.68))
                    .lineLimit(1)
                Text(primaryTitle(for: event))
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let value = event.value {
                Text(formattedValue(value, unit: event.unit))
                    .font(SparkFonts.display(.title3, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, SparkSpacing.md)
        .padding(.vertical, SparkSpacing.md)
        .background(Color.sparkElevated.opacity(0.86), in: .rect(cornerRadius: SparkRadii.lg))
        .overlay {
            RoundedRectangle(cornerRadius: SparkRadii.lg)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 6)
    }

    private var iconBox: some View {
        Image(systemName: domainIcon(event.domain))
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(Color.domainTint(for: event.domain), in: .rect(cornerRadius: 12))
    }
}

// MARK: - Standout card

private struct StandoutEventCard: View {
    let event: CachedEvent

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(metaLine(for: event))
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(Color.secondary.opacity(0.68))
                    .lineLimit(1)
                Spacer(minLength: SparkSpacing.sm)
                if let time = event.time {
                    Text(shortTime(time))
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }

            Text(primaryTitle(for: event))
                .font(SparkTypography.bodyStrong)
                .foregroundStyle(.primary)
                .lineLimit(2)

            if let value = event.value {
                HStack(spacing: SparkSpacing.xs) {
                    Text(formattedValue(value, unit: event.unit))
                        .font(SparkFonts.display(.title, weight: .bold))
                        .foregroundStyle(Color.sparkWarning)
                    Circle()
                        .fill(Color.sparkWarning)
                        .frame(width: 8, height: 8)
                }
            }

            HStack(spacing: SparkSpacing.xs) {
                if let actor = event.actorTitle, !actor.isEmpty {
                    tag(actor)
                }
                if event.domain == "money" {
                    tag("money")
                }
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sparkElevated.opacity(0.74), in: .rect(cornerRadius: SparkRadii.lg))
        .overlay {
            RoundedRectangle(cornerRadius: SparkRadii.lg)
                .stroke(Color.sparkWarning.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: Color.sparkWarning.opacity(0.14), radius: 18, x: 0, y: 10)
    }

    private func tag(_ value: String) -> some View {
        Text("# \(value)")
            .font(SparkTypography.captionStrong)
            .foregroundStyle(.secondary)
            .padding(.horizontal, SparkSpacing.sm)
            .padding(.vertical, 5)
            .background(Color.sparkSurface.opacity(0.72), in: .capsule)
            .overlay {
                Capsule()
                    .stroke(Color.primary.opacity(0.09), lineWidth: 1)
            }
    }
}

// MARK: - Web digest card

private struct WebDigestEventCard: View {
    let event: CachedEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [Color.sparkOcean.opacity(0.88), Color.sparkAccent.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "globe")
                    .font(.system(size: 54, weight: .regular))
                    .foregroundStyle(.white.opacity(0.82))
                Text(event.value ?? "Web Digest")
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, SparkSpacing.md)
                    .padding(.vertical, SparkSpacing.xs)
                    .background(Color.white.opacity(0.48), in: .capsule)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(SparkSpacing.sm)
            }
            .frame(height: 168)

            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                HStack {
                    Text(metaLine(for: event))
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(Color.secondary.opacity(0.68))
                    Spacer(minLength: SparkSpacing.sm)
                    if let time = event.time {
                        Text(shortTime(time))
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(primaryTitle(for: event))
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .padding(SparkSpacing.md)
        }
        .background(Color.sparkElevated.opacity(0.86), in: .rect(cornerRadius: SparkRadii.hero))
        .clipShape(.rect(cornerRadius: SparkRadii.hero))
        .overlay {
            RoundedRectangle(cornerRadius: SparkRadii.hero)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

// MARK: - Subtle event row

private struct SubtleEventRow: View {
    let event: CachedEvent

    var body: some View {
        HStack(alignment: .center, spacing: SparkSpacing.sm) {
            Image(systemName: domainIcon(event.domain))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            Text(metaLine(for: event))
                .font(SparkTypography.bodyStrong)
                .foregroundStyle(.primary)
                .lineLimit(1)

            if let target = event.targetTitle {
                Text(target)
                    .font(SparkTypography.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: SparkSpacing.sm)

            if let value = event.value {
                Text(formattedValue(value, unit: event.unit))
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, SparkSpacing.xs)
        .padding(.vertical, SparkSpacing.xs)
    }
}

// MARK: - Helpers

private func metaLine(for event: CachedEvent) -> String {
    let actor = event.actorTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let actor, !actor.isEmpty {
        return "\(event.action.humanisedAction) — \(actor)"
    }
    return event.action.humanisedAction
}

private func primaryTitle(for event: CachedEvent) -> String {
    event.targetTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        ?? event.actorTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        ?? event.action.humanisedAction
}

private func formattedValue(_ v: String, unit: String?) -> String {
    guard let u = unit, !u.isEmpty else { return v }
    let currencyCodes = ["GBP", "USD", "EUR", "JPY"]
    if currencyCodes.contains(u.uppercased()) {
        if let amount = Double(v.replacingOccurrences(of: ",", with: "")) {
            let fmt = NumberFormatter()
            fmt.numberStyle = .currency
            fmt.currencyCode = u
            fmt.maximumFractionDigits = 2
            return fmt.string(from: NSNumber(value: amount)) ?? "\(v) \(u)"
        }
    }
    return "\(v) \(u)"
}

private func shortTime(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}

private func domainIcon(_ domain: String) -> String {
    switch domain {
    case "health": return "moon.zzz.fill"
    case "activity": return "figure.walk"
    case "money": return "creditcard.fill"
    case "media": return "music.note"
    case "knowledge": return "book.fill"
    default: return "bolt.fill"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
