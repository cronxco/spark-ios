import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct FeedSection: View {
    let date: Date
    @State private var filter: TimelineFilter = .home
    @Query private var allEvents: [CachedEvent]

    private var rawDayEvents: [CachedEvent] {
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

    private var dayEvents: [CachedEvent] {
        rawDayEvents.filter(filter.includes)
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
        if !rawDayEvents.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                timelineHeader

                if dayEvents.isEmpty {
                    Text(emptyMessage)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, SparkSpacing.sm)
                } else {
                    ForEach(hourGroups, id: \.hour) { group in
                        HourGroup(hour: group.hour, events: group.events)
                    }
                }
            }
        }
    }

    private var timelineHeader: some View {
        HStack(alignment: .center, spacing: SparkSpacing.md) {
            Text("Timeline")
                .font(SparkFonts.display(.title2, weight: .bold))
                .lineLimit(1)
            Spacer(minLength: SparkSpacing.sm)
            TimelineFilterPill(filter: $filter)
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .home:
            "No home timeline events for this day."
        case .all:
            "No timeline events for this day."
        case .money, .health, .knowledge:
            "No \(filter.label.lowercased()) events for this day."
        }
    }
}

private enum TimelineFilter: CaseIterable {
    case home
    case money
    case health
    case knowledge
    case all

    var label: String {
        switch self {
        case .home: "Home"
        case .money: "Money"
        case .health: "Health"
        case .knowledge: "Knowledge"
        case .all: "All"
        }
    }

    var systemImage: String? {
        switch self {
        case .money: "sterlingsign.circle.fill"
        case .health: "heart.fill"
        case .knowledge: "books.vertical.fill"
        case .home, .all: nil
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .all: "Show all timeline events, including hidden events"
        default: "Show \(label.lowercased()) timeline events"
        }
    }

    func includes(_ event: CachedEvent) -> Bool {
        switch self {
        case .home:
            return !event.hidden
        case .money:
            return !event.hidden && event.domain == "money"
        case .health:
            return !event.hidden && (event.domain == "health" || event.domain == "activity")
        case .knowledge:
            return !event.hidden && event.domain == "knowledge"
        case .all:
            return true
        }
    }
}

private struct TimelineFilterPill: View {
    @Binding var filter: TimelineFilter

    private static let darkInk = Color(red: 0.086, green: 0.086, blue: 0.086)

    private let items: [(TimelineFilter, String)] = [
        (.home, "house.fill"),
        (.money, "sterlingsign"),
        (.health, "heart.fill"),
        (.knowledge, "books.vertical.fill")
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.0) { option, icon in
                Button {
                    filter = option
                } label: {
                    let isActive = filter == option
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 32, height: 28)
                        .foregroundStyle(isActive ? Self.darkInk : Color.secondary)
                        .background(isActive ? Color.sparkAccent : Color.clear, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.accessibilityLabel)
            }
        }
        .padding(3)
        .sparkGlass(.capsule)
    }
}

// MARK: - Hour group

private enum EventGroup: Identifiable {
    case single(CachedEvent)
    case collapsed(events: [CachedEvent])

    var id: String {
        switch self {
        case .single(let e): return e.id
        case .collapsed(let es): return (es.first?.id ?? "") + "_group"
        }
    }
}

private struct HourGroup: View {
    let hour: Int
    let events: [CachedEvent]

    @State private var expandedGroupIDs: Set<String> = []

    private var eventGroups: [EventGroup] {
        var result: [EventGroup] = []
        var i = 0
        while i < events.count {
            let current = events[i]
            var j = i + 1
            while j < events.count,
                  events[j].action == current.action,
                  events[j].service == current.service { j += 1 }
            let run = Array(events[i..<j])
            if run.count >= 3 {
                result.append(.collapsed(events: run))
            } else {
                result.append(contentsOf: run.map { .single($0) })
            }
            i = j
        }
        return result
    }

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
                ForEach(eventGroups) { group in
                    switch group {
                    case .single(let event):
                        NavigationLink(value: DetailRoute.event(id: event.id)) {
                            row(for: event)
                        }
                        .buttonStyle(.plain)
                    case .collapsed(let groupEvents):
                        let groupID = group.id
                        if expandedGroupIDs.contains(groupID) {
                            ForEach(groupEvents) { event in
                                NavigationLink(value: DetailRoute.event(id: event.id)) {
                                    row(for: event)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Button {
                                withAnimation(.snappy(duration: 0.22)) {
                                    _ = expandedGroupIDs.insert(groupID)
                                }
                            } label: {
                                row(for: groupEvents[0], surplusCount: groupEvents.count - 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(primaryTitle(for: groupEvents[0])), \(groupEvents.count - 1) others")
                            .accessibilityHint("Expands the grouped timeline events")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for event: CachedEvent, surplusCount: Int = 0) -> some View {
        if isWebDigest(event) {
            WebDigestEventCard(event: event, surplusCount: surplusCount)
        } else if isHeroMedia(event) {
            HeroEventCard(event: event)
        } else if isStandout(event) {
            StandoutEventCard(event: event, surplusCount: surplusCount)
        } else if isSubtle(event) {
            SubtleEventRow(event: event, surplusCount: surplusCount)
        } else {
            RaisedEventCard(event: event, surplusCount: surplusCount)
        }
    }

    private func isWebDigest(_ event: CachedEvent) -> Bool {
        event.domain == "knowledge" && (event.service == "fetch" || event.value?.lowercased().contains("web") == true)
    }

    private func isHeroMedia(_ event: CachedEvent) -> Bool {
        event.service == "untappd" ||
        (event.domain == "media" && event.value != nil)
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
    var surplusCount: Int = 0

    var body: some View {
        HStack(alignment: .center, spacing: SparkSpacing.md) {
            iconBox

            VStack(alignment: .leading, spacing: 2) {
                Text(metaLine(for: event))
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(Color.secondary.opacity(0.68))
                    .lineLimit(1)
                Text(titledWithSurplus(primaryTitle(for: event), surplus: surplusCount))
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let value = displayValue(for: event) {
                Text(value)
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
    var surplusCount: Int = 0

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

            Text(titledWithSurplus(primaryTitle(for: event), surplus: surplusCount))
                .font(SparkTypography.bodyStrong)
                .foregroundStyle(.primary)
                .lineLimit(2)

            if let value = displayValue(for: event) {
                HStack(spacing: SparkSpacing.xs) {
                    Text(value)
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
                if let count = event.blocksCount, count > 0 {
                    tag("\(count) blocks")
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
    var surplusCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let urlString = event.targetMediaUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            gradientPlaceholder
                        }
                    }
                } else {
                    gradientPlaceholder
                }
            }
            .frame(height: 168)
            .clipped()

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

                Text(titledWithSurplus(primaryTitle(for: event), surplus: surplusCount))
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

    private var gradientPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.sparkOcean.opacity(0.88), Color.sparkAccent.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "globe")
                .font(.system(size: 54, weight: .regular))
                .foregroundStyle(.white.opacity(0.82))
            Text(event.targetTitle ?? event.value ?? event.action.sparkActionTitle)
                .font(SparkTypography.captionStrong)
                .foregroundStyle(.primary)
                .padding(.horizontal, SparkSpacing.md)
                .padding(.vertical, SparkSpacing.xs)
                .background(Color.white.opacity(0.48), in: .capsule)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(SparkSpacing.sm)
        }
    }
}

// MARK: - Hero event card

private struct HeroEventCard: View {
    let event: CachedEvent

    var body: some View {
        let tint = Color.domainTint(for: event.domain)
        GlassCard(tint: tint.opacity(0.13)) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: domainIcon(event.domain))
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(tint, in: .rect(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(strippedTitle(for: event))
                        .font(SparkFonts.display(.headline, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let meta = metaLine(for: event).nilIfEmpty {
                        Text(meta)
                            .font(SparkTypography.captionStrong)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 6) {
                    if let value = displayValue(for: event) {
                        Text(value)
                            .font(SparkFonts.display(.title, weight: .bold))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    if let time = event.time {
                        Text(shortTime(time))
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.tertiary)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
        }
    }

    private func strippedTitle(for event: CachedEvent) -> String {
        var title = primaryTitle(for: event)
        for prefix in ["Finished ", "Started "] {
            if title.hasPrefix(prefix) { title = String(title.dropFirst(prefix.count)) }
        }
        return title
    }
}

// MARK: - Subtle event row

private struct SubtleEventRow: View {
    let event: CachedEvent
    var surplusCount: Int = 0

    var body: some View {
        HStack(alignment: .center, spacing: SparkSpacing.sm) {
            Image(systemName: domainIcon(event.domain))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            Text(titledWithSurplus(primaryTitle(for: event), surplus: surplusCount))
                .font(SparkTypography.bodyStrong)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: SparkSpacing.sm)

            if let value = displayValue(for: event) {
                Text(value)
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

private func titledWithSurplus(_ title: String, surplus: Int) -> String {
    surplus > 0 ? "\(title) + \(surplus) others" : title
}

private func metaLine(for event: CachedEvent) -> String {
    if isBalanceSnapshot(event), event.targetTitle?.isISODateString == true {
        return event.action.sparkActionTitle
    }
    return event.actorTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? ""
}

private func primaryTitle(for event: CachedEvent) -> String {
    if isBalanceSnapshot(event), event.targetTitle?.isISODateString == true {
        return event.actorTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? actionTitle(for: event)
    }

    return eventTitle(for: event)
}

private func eventTitle(for event: CachedEvent) -> String {
    let action = actionTitle(for: event)
    guard event.displayWithObject,
          let target = event.targetTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    else {
        return action
    }
    return "\(action) \(target)"
}

private func actionTitle(for event: CachedEvent) -> String {
    event.action.sparkActionTitle
}

private func isBalanceSnapshot(_ event: CachedEvent) -> Bool {
    event.action == "had_balance"
}

private func displayValue(for event: CachedEvent) -> String? {
    if let displayValue = event.displayValue?.sparkPlainTextFromHTMLFragment.nilIfEmpty {
        return displayValue
    }
    return event.value.map { formattedValue($0, unit: event.unit) }?.sparkPlainTextFromHTMLFragment.nilIfEmpty
}

private func formattedValue(_ v: String, unit: String?) -> String {
    let plainValue = v.sparkPlainTextFromHTMLFragment
    guard let u = unit, !u.isEmpty else { return plainValue }
    if plainValue.localizedCaseInsensitiveContains(u) {
        return plainValue
    }
    let currencyCodes = ["GBP", "USD", "EUR", "JPY"]
    if currencyCodes.contains(u.uppercased()) {
        if let amount = Double(plainValue.replacingOccurrences(of: ",", with: "")) {
            let fmt = NumberFormatter()
            fmt.numberStyle = .currency
            fmt.currencyCode = u
            fmt.maximumFractionDigits = 2
            return fmt.string(from: NSNumber(value: amount)) ?? "\(plainValue) \(u)"
        }
    }
    return "\(plainValue) \(u)"
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

    var isISODateString: Bool {
        range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }
}
