import SparkKit
import SparkUI
import SwiftData
import SwiftUI

/// The day's events, on one continuous spine.
///
/// Drawn the way the web draws them (`resources/views/livewire/day.blade.php`):
/// a single rule down the left, a service glyph per group, the action with
/// its object on the line below, the time, the pills in tiers, and the value
/// right-aligned. Each hour is a small label that pins to the top while you
/// scroll through it.
///
/// Rows carry their own vertical padding and the enclosing stack has none:
/// any spacing between them opens a gap in the spine.
struct FeedSection: View {
    let date: Date
    /// Where an hour's label pins, in the scroll view's own space: the
    /// height of the bar the page scrolls under.
    var pinnedTop: CGFloat = 0
    @State private var filter: TimelineFilter = .home
    @State private var expandedGroups: Set<String> = []
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

    /// The day in hours, newest first, each hour holding its groups.
    ///
    /// Consecutive events in the same run collapse into one group — twenty
    /// Spotify plays are one row that says twenty. A group sits in the hour
    /// of its newest event.
    private var sections: [TimelineHourSection] {
        var out: [TimelineHourSection] = []
        let events = dayEvents

        var i = 0
        while i < events.count {
            let current = events[i]
            var j = i + 1
            while j < events.count, sameRun(events[j - 1], events[j]) { j += 1 }
            let group = TimelineGroup(events: Array(events[i..<j]))

            let hour = current.time.map { Calendar.current.component(.hour, from: $0) } ?? -1
            if let last = out.indices.last, out[last].hour == hour {
                out[last].groups.append(group)
            } else {
                out.append(TimelineHourSection(hour: hour, groups: [group]))
            }
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
                    // `sections` filters, sorts and groups the day, so build it once.
                    let hours = sections
                    let firstHour = hours.first?.id
                    // Each hour's label pins to the top while you scroll
                    // through that hour, so the rows need no ring of their own.
                    // An eager stack, not a LazyVStack with pinned headers: a
                    // lazy stack nested in the page's VStack kept re-estimating
                    // its height as rows appeared, and the page would not
                    // scroll down to it.
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(hours) { section in
                            VStack(alignment: .leading, spacing: 0) {
                                // Holds the label's place; the pinned copy
                                // drawn over the section is the one you see
                                // and the one VoiceOver reads.
                                TimelineHourLabel(hour: section.hour, opensTimeline: section.id == firstHour)
                                    .opacity(0)
                                    .accessibilityHidden(true)
                                ForEach(section.groups) { group in
                                    TimelineGroupRow(
                                        events: group.events,
                                        isExpanded: expandedGroups.contains(group.id)
                                    ) {
                                        toggle(group.id)
                                    }
                                }
                            }
                            .overlay(alignment: .top) {
                                TimelinePinnedHourLabel(
                                    hour: section.hour,
                                    opensTimeline: section.id == firstHour,
                                    pinnedTop: pinnedTop
                                )
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
            .task(id: date) { expandedGroups = TimelineExpansionStore.load(for: date) }
        }
    }

    private func toggle(_ id: String) {
        withAnimation(.snappy(duration: 0.22)) {
            if expandedGroups.contains(id) {
                expandedGroups.remove(id)
            } else {
                expandedGroups.insert(id)
            }
        }
        TimelineExpansionStore.save(expandedGroups, for: date)
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

/// Whether two neighbouring events belong to one run.
///
/// The server's `group_key` is service, action and actor. Rows cached before
/// that field existed have none, and comparing their stand-in key with a
/// fresh row's real one split a run in two, so only one half showed "+N".
/// When either side has no key, compare what the key is made of instead,
/// with the actor's title for its id.
private func sameRun(_ a: CachedEvent, _ b: CachedEvent) -> Bool {
    if let left = a.groupKey, let right = b.groupKey {
        return left == right
    }
    return a.service == b.service
        && a.action == b.action
        && (a.actorTitle ?? "") == (b.actorTitle ?? "")
}

private struct TimelineHourSection: Identifiable {
    let hour: Int
    var groups: [TimelineGroup]

    var id: Int { hour }
}

private struct TimelineGroup: Identifiable {
    let events: [CachedEvent]

    /// Stable while new plays arrive: newer events join the top of a run,
    /// so the oldest event and the run's key name it.
    var id: String {
        guard let oldest = events.last else { return UUID().uuidString }
        let key = oldest.groupKey ?? "\(oldest.service):\(oldest.action)"
        return "\(key)|\(oldest.id)"
    }
}

/// Which groups are open on a day, kept per day like the web's
/// `day-collapsed-groups-{date}`. Groups start collapsed.
private enum TimelineExpansionStore {
    private static func key(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "spark.timeline.expanded.%04d-%02d-%02d",
            components.year ?? 0, components.month ?? 0, components.day ?? 0
        )
    }

    static func load(for date: Date) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key(for: date)) ?? [])
    }

    static func save(_ ids: Set<String>, for date: Date) {
        if ids.isEmpty {
            UserDefaults.standard.removeObject(forKey: key(for: date))
        } else {
            UserDefaults.standard.set(Array(ids).sorted(), forKey: key(for: date))
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
/// - between events: 24 (12 above and below each row)
/// - an hour label: 12 above (4 for the first), 4 below
private enum TimelineRhythm {
    static let insideEvent = SparkSpacing.xs
    static let betweenTiers = SparkSpacing.sm
    static let eventPadding = SparkSpacing.md
    static let hourLeading = SparkSpacing.md
    static let hourTrailing = SparkSpacing.xs
    static let firstHourLeading = SparkSpacing.xs
    /// Block pills shown before a "+N" pill, matching the server's cap.
    static let blockLimit = 3
    /// The diameter of an expanded row's dot on the spine.
    static let childDot: CGFloat = 8
}

/// An hour's label drawn over its section, moved down with the scroll so it
/// stays at the top of the page until the section's end pushes it off.
/// The move is a visual effect, so it never changes the layout under the
/// scroll. It takes no touches, so the rows beneath it stay tappable, but
/// VoiceOver reads it as the hour's header.
private struct TimelinePinnedHourLabel: View {
    let hour: Int
    let opensTimeline: Bool
    let pinnedTop: CGFloat

    /// About the label's height with its padding, so it leaves its section
    /// before overlapping the next hour's label.
    private static let labelHeight: CGFloat = 36

    var body: some View {
        let pinnedTop = pinnedTop
        let labelHeight = Self.labelHeight
        Color.clear
            .overlay(alignment: .top) {
                TimelineHourLabel(hour: hour, opensTimeline: opensTimeline)
            }
            .visualEffect { content, proxy in
                let frame = proxy.frame(in: .scrollView(axis: .vertical))
                let pinned = max(0, pinnedTop - frame.minY)
                let limit = max(0, frame.height - labelHeight)
                return content.offset(y: min(pinned, limit))
            }
            .allowsHitTesting(false)
    }
}

/// The hour as a small label ("14:00") that pins to the top of the page
/// while you scroll through that hour. Opaque, so rows pass behind it.
private struct TimelineHourLabel: View {
    let hour: Int
    /// The first label sits under the section header, which already
    /// separates it, so it skips the gap between hours.
    var opensTimeline = false

    var body: some View {
        HStack(spacing: 0) {
            Text(hour >= 0 ? String(format: "%02d:00", hour) : "Undated")
                .font(SparkTypography.captionStrong)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, SparkSpacing.sm)
                .padding(.vertical, SparkSpacing.xxs)
                .background(Color.sparkSurface, in: .capsule)
                .overlay { Capsule().strokeBorder(Color.primary.opacity(0.13), lineWidth: 1) }
            Spacer(minLength: 0)
        }
        .padding(.top, opensTimeline ? TimelineRhythm.firstHourLeading : TimelineRhythm.hourLeading)
        .padding(.bottom, TimelineRhythm.hourTrailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hour >= 0 ? String(format: "%02d:00", hour) : "Undated")
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - One group

/// A run of events: the newest as the row, the rest folded behind "+N".
/// The glyph (or "+N") opens and closes the group; the rest of the row opens
/// the event.
private struct TimelineGroupRow: View {
    let events: [CachedEvent]
    let isExpanded: Bool
    let onToggle: () -> Void

    private var lead: CachedEvent { events[0] }
    private var surplus: Int { events.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(value: DetailRoute.event(id: lead.id)) {
                TimelineRow(
                    event: lead,
                    style: .lead(surplus: surplus, isExpanded: isExpanded, onToggle: surplus > 0 ? onToggle : nil)
                )
            }
            .buttonStyle(.plain)
            .sparkAppEntityIdentifier(type: "event", identifier: lead.id)

            if isExpanded {
                ForEach(events.dropFirst()) { event in
                    NavigationLink(value: DetailRoute.event(id: event.id)) {
                        TimelineRow(event: event, style: .child)
                    }
                    .buttonStyle(.plain)
                    .sparkAppEntityIdentifier(type: "event", identifier: event.id)
                }
            }
        }
    }
}

/// One event, laid out like the web day view: the action, then its object
/// on a line of its own, then the exact and relative time, then the pills in
/// tiers (where it came from, its tags, its blocks), each capped with "+N".
private struct TimelineRow: View {
    enum Style {
        /// A group's newest event, with its glyph on the spine. `onToggle`
        /// is set when the group has more than one event.
        case lead(surplus: Int, isExpanded: Bool, onToggle: (() -> Void)?)
        /// One of the events an open group shows under its lead: a dot on
        /// the spine, so each still reads as a point in time.
        case child
    }

    let event: CachedEvent
    let style: Style

    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color { EntityPresentation.tint(domain: event.domain) }

    /// "+N others" shows only while the group is closed.
    private var hiddenCount: Int {
        if case .lead(let surplus, let isExpanded, _) = style, !isExpanded { return surplus }
        return 0
    }

    private var toggle: (() -> Void)? {
        if case .lead(_, _, let onToggle) = style { return onToggle }
        return nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: SparkSpacing.md) {
            SpineColumn { node }

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
                    .font(valueFont)
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, TimelineRhythm.eventPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        // The combined row opens the event, so VoiceOver reaches the
        // group's toggle as an action.
        .accessibilityActions {
            if case .lead(let surplus, let isExpanded, let onToggle?) = style {
                Button(isExpanded ? "Hide \(surplus) more" : "Show \(surplus) more", action: onToggle)
            }
        }
    }

    /// The glyph for a lead row, a dot for an expanded one. The column is
    /// never empty: an empty view takes no space in an HStack, which is how
    /// expanded rows lost their column and ran into the spine.
    @ViewBuilder
    private var node: some View {
        switch style {
        case .child:
            Circle()
                .fill(tint)
                .frame(width: TimelineRhythm.childDot, height: TimelineRhythm.childDot)
                .padding(.top, 12)
        case .lead(let surplus, let isExpanded, let onToggle):
            let glyph = DomainGlyph(
                SparkIcon.event(action: event.action, service: event.service, domain: event.domain),
                tint: tint,
                size: 30,
                backing: .sparkSurface
            )
            if let onToggle {
                Button(action: onToggle) { glyph }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Hide \(surplus) more" : "Show \(surplus) more")
            } else {
                glyph
            }
        }
    }

    /// Money is the figure people scan the timeline for, so it keeps the
    /// display face, a step under the title. Durations, scores and counts
    /// are detail and read at body size.
    private var isMoney: Bool { event.domain == "money" }

    private var valueFont: Font {
        isMoney
            ? SparkFonts.display(.headline, weight: .bold)
            : SparkTypography.body.weight(.semibold)
    }

    /// Money takes its domain's tint in dark mode, like the card heroes, and
    /// ink in light mode, since the tints are fills there and do not clear
    /// 4.5:1 as text. Other values are secondary.
    private var valueColor: Color {
        guard isMoney else { return .secondary }
        return colorScheme == .dark ? tint : .primary
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
            if hiddenCount > 0, let toggle = toggle {
                Button(action: toggle) {
                    Text("+ \(hiddenCount) other" + (hiddenCount == 1 ? "" : "s"))
                        .font(SparkTypography.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show \(hiddenCount) more")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var tiers: some View {
        VStack(alignment: .leading, spacing: TimelineRhythm.betweenTiers) {
            if let source = sourceTitle(for: event) {
                TimelineSourcePill(title: source, service: event.service, domain: event.domain)
            }
            let tags = timelineTags(event.decodedTags)
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
        if hiddenCount > 0 { parts.append("and \(hiddenCount) more") }
        if let time = event.time { parts.append(Self.absolute.string(from: time)) }
        if let value = signedValue(for: event) { parts.append(value) }
        if let source = sourceTitle(for: event) { parts.append("from \(source)") }
        let tags = timelineTags(event.decodedTags).map(\.displayName)
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
        .sparkWidthCap(240)
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

/// The event's tags on one line: as many as fit, then "+N" in the same
/// outline, which opens the tier onto as many lines as it needs.
private struct TimelineTagTier: View {
    let tags: [EventTag]
    @State private var showsAll = false

    private static let spacing = SparkSpacing.xs + SparkSpacing.xxs

    var body: some View {
        if showsAll {
            FlowLayout(spacing: Self.spacing, lineSpacing: TimelineRhythm.insideEvent + SparkSpacing.xxs) {
                ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                    DetailTagChip(tag: tag)
                }
            }
        } else {
            // The first arrangement that fits wins: every tag, then one fewer
            // with "+1", and so on down to "+N" alone.
            ViewThatFits(in: .horizontal) {
                ForEach(Array(stride(from: tags.count, through: 0, by: -1)), id: \.self) { shown in
                    line(showing: shown)
                }
            }
        }
    }

    private func line(showing shown: Int) -> some View {
        HStack(spacing: Self.spacing) {
            ForEach(Array(tags.prefix(shown).enumerated()), id: \.offset) { _, tag in
                DetailTagChip(tag: tag)
            }
            let hidden = tags.count - shown
            if hidden > 0 {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { showsAll = true }
                } label: {
                    TimelineMoreTagPill(count: hidden)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show \(hidden) more tags")
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// "+N" at the end of a tag line, in the tags' outline so it reads as one
/// more of them.
private struct TimelineMoreTagPill: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(SparkTypography.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, SparkSpacing.sm)
            .padding(.vertical, SparkSpacing.xxs)
            .overlay { Capsule().strokeBorder(Color.primary.opacity(0.25), lineWidth: 1) }
            .contentShape(.capsule)
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
        .sparkWidthCap(260)
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

/// The tags a timeline row shows: unique, and without the bank's own
/// bookkeeping. The event screen still shows every tag.
private func timelineTags(_ tags: [EventTag]) -> [EventTag] {
    uniqueTags(tags).filter { !isMachineTag($0) }
}

/// Tag types that describe how a transaction was processed rather than what
/// it was for: its currency, status, debit or credit, payment scheme
/// ("uk_retail_pot"), card number, balance type and merchant metadata.
private let machineTagTypes: Set<String> = [
    "transaction_currency", "transaction_status", "transaction_type",
    "transaction_scheme", "card_pan", "balance_type",
    "merchant_emoji", "merchant_country", "currency",
]

private let currencyCodes = Set(Locale.Currency.isoCurrencies.map(\.identifier))

private func isMachineTag(_ tag: EventTag) -> Bool {
    let type = (tag.type ?? "").lowercased()
    // A declined payment is worth seeing at a glance.
    if type == "transaction_status", tag.name.lowercased() == "declined" { return false }
    if machineTagTypes.contains(type) { return true }
    // Rows cached before tags kept their type: a bare currency code.
    if type.isEmpty, currencyCodes.contains(tag.name) { return true }
    return false
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
