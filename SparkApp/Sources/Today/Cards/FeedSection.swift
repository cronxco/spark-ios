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
            SectionLabel("Timeline", style: .dayHeading)
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
    static var width: CGFloat { 30 }

    @ViewBuilder var node: () -> Node

    var body: some View {
        node()
            .frame(width: Self.width, alignment: .top)
    }
}

private struct TimelineHourMarker: View {
    let hour: Int

    var body: some View {
        HStack(alignment: .center, spacing: SparkSpacing.md) {
            SpineColumn {
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .padding(3)
                    .background(Color.sparkSurface, in: .circle)
            }
            Text(String(format: "%02d:00", hour))
                .font(SparkTypography.captionStrong)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .frame(height: 30)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "%02d:00", hour))
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
                    DomainGlyph(
                        SparkIcon.domain(event.domain),
                        tint: EntityPresentation.tint(domain: event.domain),
                        size: 30,
                        backing: .sparkSurface
                    )
                }
            }

            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                sentence
                meta
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)

            if let value = signedValue(for: event) {
                Text(value)
                    .font(SparkFonts.display(.body, weight: .bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 5)
            }
        }
        .padding(.vertical, SparkSpacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// "Paid [Brother Marcus] + 2 others": the action, its object as a
    /// reference pill showing the title only (`docs/design-language.md`
    /// section 7.5), and the surplus count quiet.
    private var sentence: some View {
        FlowLayout(spacing: SparkSpacing.xs) {
            Text(actionTitle(for: event))
                .font(SparkTypography.body)
                .foregroundStyle(.primary)
            if event.displayWithObject,
               let target = event.targetTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                ObjectRefPill(title: target, type: event.targetType)
            }
            if surplus > 0 {
                Text("+ \(surplus) other" + (surplus == 1 ? "" : "s"))
                    .font(SparkTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The time (relative, exact on a tap), the actor, and every tag as an
    /// outline pill. No dividers between them: the spacing separates.
    private var meta: some View {
        FlowLayout(spacing: SparkSpacing.sm) {
            if let time = event.time {
                SparkTimeText(time)
            }
            if let source = metaLine(for: event).nilIfEmpty {
                Text(source)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 180, alignment: .leading)
            }
            ForEach(event.decodedTags) { tag in
                TagChip(tag)
            }
        }
    }

    private var accessibilityLabel: String {
        var parts = [primaryTitle(for: event)]
        if surplus > 0 { parts.append("and \(surplus) more") }
        if let time = event.time { parts.append(Self.absolute.string(from: time)) }
        if let value = signedValue(for: event) { parts.append(value) }
        let tags = event.decodedTagNames
        if !tags.isEmpty { parts.append("tagged " + tags.joined(separator: ", ")) }
        return parts.joined(separator: ", ")
    }

    private static let absolute: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        return f
    }()
}

/// An object reference: the title only, in its concept's role colour, on a
/// 10% fill with a 20% border. Text takes the role's ink.
private struct ObjectRefPill: View {
    let title: String
    let type: String?

    var body: some View {
        let role = SparkRole.forObjectType(type)
        HStack(spacing: SparkSpacing.xs) {
            SparkGlyph(Self.icon(forType: type), size: 11, relativeTo: .subheadline)
                .opacity(0.8)
            Text(title)
                .font(SparkTypography.bodySmall.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(role.ink)
        .padding(.horizontal, SparkSpacing.sm)
        .padding(.vertical, 2)
        .frame(maxWidth: 220, alignment: .leading)
        .background(role.fill.opacity(0.10), in: .capsule)
        .overlay { Capsule().strokeBorder(role.fill.opacity(0.20), lineWidth: 1) }
    }

    private static func icon(forType type: String?) -> SparkIcon {
        let type = (type ?? "").lowercased()
        if type.contains("person") || type.contains("user") || type.contains("contact") { return .person }
        if type.contains("album") { return .album }
        if type.contains("artist") { return .artist }
        if type.contains("track") || type.contains("song") || type.contains("episode") { return .track }
        if type.contains("book") && !type.contains("bookmark") { return .book }
        if type.contains("article") || type.contains("bookmark") || type.contains("document") { return .article }
        if type.contains("account") || type.contains("merchant") || type.contains("money") { return .payment }
        if type.contains("place") || type.contains("location") { return .place }
        return .link
    }
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
                        .frame(width: 44, height: 44)
                        .foregroundStyle(isActive ? Color.sparkOnAccent : Color.secondary)
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var isISODateString: Bool {
        range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }
}
