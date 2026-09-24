import SparkKit
import SparkUI
import SwiftData
import SwiftUI

/// The day's events, on one continuous spine.
///
/// Drawn the way the web draws them (`resources/views/livewire/day.blade.php`):
/// a single rule down the left, an hour pip on it, a service node per group,
/// the action written as a sentence with its object as a link, and the value
/// right-aligned. The iOS version this replaces ruled every hour off and
/// changed a row's weight with what kind of event it was, which made the page
/// a stack of unrelated cards rather than a day.
///
/// Rows carry their own vertical padding and the enclosing stack has none:
/// any spacing between them opens a gap in the spine.
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

    /// Consecutive events sharing the server's `group_key` collapse into one
    /// row — twenty Spotify plays are one line that says twenty. The key is
    /// decided server-side so the web and the app group identically.
    private var rows: [TimelineEntry] {
        var out: [TimelineEntry] = []
        var previousHour: Int?
        let events = dayEvents

        var i = 0
        while i < events.count {
            let current = events[i]
            let key = runKey(for: current)
            var j = i + 1
            while j < events.count, runKey(for: events[j]) == key { j += 1 }
            let run = Array(events[i..<j])

            if let time = current.time {
                let hour = Calendar.current.component(.hour, from: time)
                if hour != previousHour {
                    out.append(.hour(hour))
                    previousHour = hour
                }
            }
            out.append(.group(run))
            i = j
        }
        return out
    }

    var body: some View {
        if !rawDayEvents.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                timelineHeader

                if dayEvents.isEmpty {
                    Text(emptyMessage)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, SparkSpacing.sm)
                } else {
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            switch row {
                            case .hour(let hour):
                                TimelineHourMarker(hour: hour)
                            case .group(let events):
                                TimelineGroupRow(events: events)
                            }
                        }
                    }
                    // The spine is drawn once behind every row, where it gets
                    // the stack's final height. Inside a row it only ever got
                    // that row's node column, which is shorter than a row whose
                    // text wraps, and the rule broke off between rows.
                    .background(alignment: .leading) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.13))
                            .frame(width: 1)
                            .padding(.leading, (SpineColumn<EmptyView>.width - 1) / 2)
                    }
                }
            }
        }
    }

    private var timelineHeader: some View {
        HStack(alignment: .center, spacing: SparkSpacing.md) {
            SectionLabel("Timeline")
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

/// The server's run key, or — for rows cached before the field existed —
/// the service and action the client used to group on. The fallback drops
/// the actor, so it can merge runs the server would keep apart; it lasts
/// only until the cache refreshes.
private func runKey(for event: CachedEvent) -> String {
    event.groupKey ?? "\(event.service):\(event.action)"
}

private enum TimelineEntry: Identifiable {
    case hour(Int)
    case group([CachedEvent])

    var id: String {
        switch self {
        case .hour(let h): "hour_\(h)"
        case .group(let events): events.first?.id ?? UUID().uuidString
        }
    }
}

// MARK: - The spine

/// The column the spine runs down. The rule itself is drawn behind the whole
/// timeline by `FeedSection`; this places a row's node on it, masked by the
/// page colour so the line appears to pass behind.
private struct SpineColumn<Node: View>: View {
    static var width: CGFloat { 26 }

    @ViewBuilder var node: () -> Node

    var body: some View {
        node()
            .frame(width: Self.width, alignment: .top)
    }
}

private struct TimelineHourMarker: View {
    let hour: Int

    var body: some View {
        HStack(alignment: .top, spacing: SparkSpacing.md) {
            SpineColumn {
                Text(String(format: "%02d", hour))
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 22, height: 22)
                    .background(Color.sparkSurface, in: .circle)
                    .overlay { Circle().stroke(Color.primary.opacity(0.13), lineWidth: 1) }
                    .offset(y: 4)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 30)
        .accessibilityLabel("\(hour) hundred hours")
    }
}

// MARK: - One group

private struct TimelineGroupRow: View {
    let events: [CachedEvent]
    @State private var isExpanded = false

    private var lead: CachedEvent { events[0] }
    private var surplus: Int { events.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            if surplus > 0, !isExpanded {
                Button {
                    withAnimation(.snappy(duration: 0.22)) { isExpanded = true }
                } label: {
                    TimelineRow(event: lead, surplus: surplus, isChild: false)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Expands \(surplus) more")
            } else {
                NavigationLink(value: DetailRoute.event(id: lead.id)) {
                    TimelineRow(event: lead, surplus: 0, isChild: false)
                }
                .buttonStyle(.plain)
                .sparkAppEntityIdentifier(type: "event", identifier: lead.id)

                if isExpanded {
                    ForEach(events.dropFirst()) { event in
                        NavigationLink(value: DetailRoute.event(id: event.id)) {
                            TimelineRow(event: event, surplus: 0, isChild: true)
                        }
                        .buttonStyle(.plain)
                        .sparkAppEntityIdentifier(type: "event", identifier: event.id)
                    }
                }
            }
        }
    }
}

private struct TimelineRow: View {
    let event: CachedEvent
    let surplus: Int
    let isChild: Bool

    var body: some View {
        HStack(alignment: .top, spacing: SparkSpacing.md) {
            SpineColumn {
                if !isChild {
                    Image(systemName: domainIcon(event.domain))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.domainTint(for: event.domain))
                        .frame(width: 26, height: 26)
                        .background(Color.sparkSurface, in: .circle)
                        .overlay {
                            Circle().stroke(
                                Color.domainTint(for: event.domain).opacity(0.35),
                                lineWidth: 1.5
                            )
                        }
                        .offset(y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                sentence
                meta
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 3)
            .padding(.bottom, SparkSpacing.sm)

            if let value = signedValue(for: event) {
                Text(value)
                    .font(SparkFonts.display(.body, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// "Paid Brother Marcus + 2 others" — the action in ink, its object in the
    /// link colour, the surplus count quiet.
    ///
    /// Built by interpolating styled `Text` into `Text`: concatenating with
    /// `+` is deprecated on this SDK, and warnings are errors.
    private var sentence: Text {
        var line = Text(actionTitle(for: event)).fontWeight(.semibold)
        if event.displayWithObject,
           let target = event.targetTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !target.isEmpty {
            let object = Text(target)
                .fontWeight(.semibold)
                .foregroundStyle(Color.sparkOcean)
            line = Text("\(line) \(object)")
        }
        if surplus > 0 {
            let others = "+ \(surplus) other" + (surplus == 1 ? "" : "s")
            let more = Text(others).foregroundStyle(Color.secondary)
            line = Text("\(line) \(more)")
        }
        return line
    }

    @ViewBuilder
    private var meta: some View {
        HStack(spacing: 4) {
            // Relative only. The absolute time is on the event's own screen,
            // one tap away, and in this row's accessible name.
            if let time = event.time {
                Text(Self.relative.localizedString(for: time, relativeTo: .now))
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            }
            if let source = metaLine(for: event).nilIfEmpty {
                Text("·").font(SparkTypography.monoSmall).foregroundStyle(.tertiary)
                Text(source)
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            ForEach(event.decodedTagNames.prefix(2), id: \.self) { tag in
                Text("·").font(SparkTypography.monoSmall).foregroundStyle(.tertiary)
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.sparkTagTopic)
                        .frame(width: 5, height: 5)
                    Text(tag)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .lineLimit(1)
    }

    private var accessibilityLabel: String {
        var parts = [primaryTitle(for: event)]
        if surplus > 0 { parts.append("and \(surplus) more") }
        if let time = event.time { parts.append(Self.absolute.string(from: time)) }
        if let value = signedValue(for: event) { parts.append(value) }
        return parts.joined(separator: ", ")
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private static let absolute: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}

/// Money moving out takes a minus and money coming in a plus, so direction is
/// carried by the sign rather than by colour — the status colours are fills in
/// light mode and do not clear 4.5:1 as text.
///
/// Direction is the server's (`CompactEvent.direction`). Money moved between
/// the user's own accounts is neither in nor out, so it carries no sign; nor
/// does anything the server has not classified. There is no guessing from
/// action names here any more.
private func signedValue(for event: CachedEvent) -> String? {
    guard let value = displayValue(for: event) else { return nil }
    guard event.domain == "money" else { return value }
    guard !value.hasPrefix("-"), !value.hasPrefix("\u{2212}"), !value.hasPrefix("+") else { return value }

    switch event.direction {
    case "out"?: return "\u{2212}" + value
    case "in"?: return "+" + value
    default: return value
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
