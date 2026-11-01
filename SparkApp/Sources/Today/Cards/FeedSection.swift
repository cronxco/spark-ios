import SparkKit
import SparkUI
import SwiftData
import SwiftUI

/// The day's events, on one continuous spine.
///
/// Drawn the way the web draws them (`resources/views/livewire/day.blade.php`):
/// a single rule down the left, each hour as a node on it, a service node per
/// group, the action with its object on the line below, the time, the pills
/// in tiers, and the value right-aligned. The iOS version this replaces ruled every hour off and
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
                    // `rows` filters, sorts and groups the day, so build it once.
                    let entries = rows
                    let firstEntryID = entries.first?.id
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(entries) { row in
                            switch row {
                            case .hour(let hour):
                                TimelineHourMarker(hour: hour, opensTimeline: row.id == firstEntryID)
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

/// The timeline's vertical rhythm, on the 4 pt grid (`SparkSpacing`).
/// Proximity does the grouping, so the gaps step up from inside an event, to
/// between events, to between hours:
/// - inside an event: 4 between the title, the time and each pill row
/// - an hour node to its first event: 16, so the node reads as that hour's
///   heading rather than the previous hour's footer
/// - between events in the same hour: 24
/// - between hours: 36
private enum TimelineRhythm {
    static let insideEvent = SparkSpacing.xs
    static let betweenTiers = SparkSpacing.sm
    static let eventPadding = SparkSpacing.md
    static let hourLeading = SparkSpacing.xl
    static let hourTrailing = SparkSpacing.xs
    static let firstHourLeading = SparkSpacing.xs
    /// Block pills shown before a "+N" pill, matching the server's cap.
    static let blockLimit = 3
    /// Tags shown before a "+N" pill, as the web caps block pills at three.
    static let tagLimit = 5
}

/// The hour as a node on the spine ("09" in a ring), as on the web.
private struct TimelineHourMarker: View {
    let hour: Int
    /// The first marker sits under the section header, which already
    /// separates it, so it skips the gap between hours.
    var opensTimeline = false

    var body: some View {
        HStack(spacing: 0) {
            SpineColumn {
                Text(String(format: "%02d", hour))
                    .font(SparkTypography.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.sparkSurface, in: .circle)
                    .overlay { Circle().strokeBorder(Color.primary.opacity(0.13), lineWidth: 1) }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, opensTimeline ? TimelineRhythm.firstHourLeading : TimelineRhythm.hourLeading)
        .padding(.bottom, TimelineRhythm.hourTrailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "%02d:00", hour))
        .accessibilityAddTraits(.isHeader)
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

/// One event, laid out like the web day view: the action, then its object
/// on a line of its own, then the exact and relative time, then the pills in
/// tiers (where it came from, its tags, its blocks), each capped with "+N".
private struct TimelineRow: View {
    let event: CachedEvent
    let surplus: Int
    let isChild: Bool

    @Environment(\.colorScheme) private var colorScheme

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

            VStack(alignment: .leading, spacing: TimelineRhythm.insideEvent) {
                title
                if let time = event.time {
                    TimelineTimeText(date: time)
                }
                tiers
                    .padding(.top, TimelineRhythm.insideEvent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)

            if let value = signedValue(for: event) {
                Text(value)
                    .font(SparkFonts.display(.title3, weight: .bold))
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, TimelineRhythm.eventPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Values take their domain's tint in dark mode, like the card heroes;
    /// light mode keeps them in ink, since the tints are fills there and do
    /// not clear 4.5:1 as text.
    private var valueColor: Color {
        colorScheme == .dark ? EntityPresentation.tint(domain: event.domain) : .primary
    }

    /// The action, then its object in full on its own line, so a long title
    /// wraps instead of being cut off inside a pill.
    private var title: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(actionTitle(for: event))
                .font(SparkTypography.title.weight(.semibold))
                .foregroundStyle(.primary)
            if let object = objectTitle(for: event) {
                Text(object)
                    .font(SparkTypography.title)
                    .foregroundStyle(.primary)
            }
            if surplus > 0 {
                Text("+ \(surplus) other" + (surplus == 1 ? "" : "s"))
                    .font(SparkTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var tiers: some View {
        VStack(alignment: .leading, spacing: TimelineRhythm.betweenTiers) {
            if let source = sourceTitle(for: event) {
                TimelineSourcePill(title: source, service: event.service, domain: event.domain)
            }
            let tags = uniqueTags(event.decodedTags)
            if !tags.isEmpty {
                TimelineTagTier(tags: tags)
            }
            let blocks = event.decodedBlockRefs
            if !blocks.isEmpty {
                let shown = Array(blocks.prefix(TimelineRhythm.blockLimit))
                TimelineBlockTier(
                    blocks: shown,
                    hidden: max(event.blockRefsTotal ?? blocks.count, blocks.count) - shown.count
                )
            }
        }
    }

    private var accessibilityLabel: String {
        var parts = [primaryTitle(for: event)]
        if surplus > 0 { parts.append("and \(surplus) more") }
        if let time = event.time { parts.append(Self.absolute.string(from: time)) }
        if let value = signedValue(for: event) { parts.append(value) }
        if let source = sourceTitle(for: event) { parts.append("from \(source)") }
        let tags = uniqueTags(event.decodedTags).map(\.name)
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

/// "20:00  in 57 minutes": the exact time first, then the relative one,
/// separated by a gap rather than a divider.
private struct TimelineTimeText: View {
    let date: Date

    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(spacing: SparkSpacing.sm) {
                Text(Self.exact.string(from: date))
                Text(Self.relative.localizedString(for: date, relativeTo: context.date))
            }
            .font(SparkTypography.bodySmall)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private static let exact: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
}

// MARK: - Pill tiers

/// Where the event came from: the integration instance ("Current Account"),
/// or the actor when the feed has not sent one yet. Opens the integration.
private struct TimelineSourcePill: View {
    let title: String
    let service: String
    let domain: String

    @Environment(\.openDetailRoute) private var openDetailRoute

    var body: some View {
        let pill = HStack(spacing: SparkSpacing.xs) {
            SparkGlyph(SparkIcon.domain(domain), size: 11, relativeTo: .subheadline)
                .opacity(0.7)
            Text(title)
                .font(SparkTypography.bodySmall.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: 240, alignment: .leading)
        .padding(.horizontal, SparkSpacing.sm)
        .padding(.vertical, 2)
        .overlay {
            RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: 6))

        if let openDetailRoute {
            Button { openDetailRoute(.integration(service: service)) } label: { pill }
                .buttonStyle(.plain)
                .accessibilityLabel("From \(title)")
        } else {
            pill
        }
    }
}

/// The event's tags, the first few and then "+N", which shows the rest.
private struct TimelineTagTier: View {
    let tags: [EventTag]
    @State private var showsAll = false

    var body: some View {
        let shown = showsAll ? tags : Array(tags.prefix(TimelineRhythm.tagLimit))
        let hidden = tags.count - shown.count
        FlowLayout(spacing: SparkSpacing.xs + SparkSpacing.xxs, lineSpacing: TimelineRhythm.insideEvent + SparkSpacing.xxs) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, tag in
                DetailTagChip(tag: tag)
            }
            if hidden > 0 {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { showsAll = true }
                } label: {
                    TimelineMorePill(count: hidden)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show \(hidden) more tags")
            }
        }
    }
}

/// The event's first blocks as pills, each with its value ("Tax Summary
/// £1.20"), then "+N" for the rest, which live on the event screen.
private struct TimelineBlockTier: View {
    let blocks: [Event.BlockRef]
    let hidden: Int

    @Environment(\.openDetailRoute) private var openDetailRoute

    var body: some View {
        FlowLayout(spacing: SparkSpacing.xs + SparkSpacing.xxs, lineSpacing: TimelineRhythm.insideEvent + SparkSpacing.xxs) {
            ForEach(blocks) { block in
                if let openDetailRoute {
                    Button { openDetailRoute(.block(id: block.id)) } label: { TimelineBlockPill(block: block) }
                        .buttonStyle(.plain)
                } else {
                    TimelineBlockPill(block: block)
                }
            }
            if hidden > 0 {
                TimelineMorePill(count: hidden)
                    .accessibilityLabel("\(hidden) more blocks")
            }
        }
    }
}

private struct TimelineBlockPill: View {
    let block: Event.BlockRef

    var body: some View {
        let kind = BlockKind(blockType: block.blockType, hasValue: block.displayValue != nil)
        let role = SparkRole.forDomain(kind.domain)
        HStack(spacing: SparkSpacing.xs) {
            Image(systemName: kind.systemImage)
                .font(.caption2.weight(.semibold))
                .opacity(0.8)
            Text(block.title)
                .font(SparkTypography.bodySmall.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
            if let value = block.displayValue {
                Text(value)
                    .font(SparkTypography.bodySmall.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .foregroundStyle(role.ink)
        .frame(maxWidth: 260, alignment: .leading)
        .padding(.horizontal, SparkSpacing.sm)
        .padding(.vertical, 2)
        .background(role.fill.opacity(0.10), in: .rect(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6).strokeBorder(role.fill.opacity(0.20), lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([block.title, block.displayValue].compactMap { $0 }.joined(separator: ", "))
    }
}

/// "+N": the items a tier holds back.
private struct TimelineMorePill: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(SparkTypography.bodySmall.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, SparkSpacing.sm)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 6))
    }
}

/// Tags with the same name and type once only: integrations sometimes
/// attach a tag twice ("eating_out" from both the category and the merchant).
private func uniqueTags(_ tags: [EventTag]) -> [EventTag] {
    var seen = Set<String>()
    return tags.filter { tag in
        let key = "\(tag.name.lowercased())\u{1E}\((tag.type ?? "").lowercased())"
        return seen.insert(key).inserted
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

/// The object written on the line under the action: the target, or the
/// actor when there is no target, as on the web. A balance snapshot's target
/// is a date, so it names the account instead.
private func objectTitle(for event: CachedEvent) -> String? {
    let actor = event.actorTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    if isBalanceSnapshot(event), event.targetTitle?.isISODateString == true {
        return actor
    }
    guard event.displayWithObject else { return nil }
    return event.targetTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? actor
}

/// Where the event came from, for the first pill: the integration instance,
/// or the actor until the feed has sent the integration. Left out when it
/// would repeat the object line.
private func sourceTitle(for event: CachedEvent) -> String? {
    if let name = event.integrationName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
        return name
    }
    let actor = event.actorTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    return actor == objectTitle(for: event) ? nil : actor
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
