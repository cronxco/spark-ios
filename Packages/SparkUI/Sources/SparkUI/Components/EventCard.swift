import SparkKit
import SwiftUI

public extension EventKind {
    /// The glyph for each kind (design language §6). `.generic` falls back
    /// to the event's domain.
    func systemImage(domain: String?) -> String {
        switch self {
        case .sleepScore, .sleepDuration: "moon.zzz.fill"
        case .readinessScore: "gauge.with.needle"
        case .activityScore: "figure.run"
        case .steps: "figure.walk"
        case .exerciseTime: "clock"
        case .generic: EntityPresentation.icon(domain: domain)
        }
    }
}

/// The one view that draws an event as a card.
///
/// Cards sit under a Flint briefing paragraph in Up to Speed (design
/// language §7.3). The backend names each card's layout:
///
/// - `.metric`: eyebrow, the live value (a ring for scores, a bar against
///   the mean for durations and counts) and one comparison line. Two or
///   three across, or wide when alone, with the ring or bar trailing.
/// - `.journey`: a flight. Airport codes as the hero, local times under each,
///   joined by a route line whose plane moves while the flight is in the air.
/// - `.calendar`: a calendar entry's title and time span.
/// - `.payment`: amount, merchant, account and Pending, with a strip of the
///   week's payments.
/// - `.reading`: publication, the article's own headline, read time and up
///   to four takeaways.
///
/// Every card sits on its domain-tinted fill, still opaque content (§5.3),
/// and ends with the reader's answer when they answered a Flint question
/// about the event. `drawn` lets the row draw rings and routes in once.
public struct EventCard: View {
    public enum Size: Sendable {
        /// Up to three across under a paragraph: eyebrow, value, context.
        case compact
        /// The whole row: a lone metric card, or any other layout.
        case wide
    }

    let card: LinkedEventCard
    let size: Size
    let drawn: Bool

    @Environment(\.colorSchemeContrast) private var contrast
    /// §4: a 24pt compact hero with its unit at about 55%, scaling together.
    @ScaledMetric(relativeTo: .title2) private var heroSize: CGFloat = 24
    @ScaledMetric(relativeTo: .title2) private var unitSize: CGFloat = 13
    @ScaledMetric(relativeTo: .title) private var airportSize: CGFloat = 30
    @ScaledMetric(relativeTo: .caption) private var chipSize: CGFloat = 22

    public init(_ card: LinkedEventCard, size: Size = .compact, drawn: Bool = true) {
        self.card = card
        self.size = card.layout.isWide ? .wide : size
        self.drawn = drawn
    }

    private var kind: EventKind { card.kind }
    private var details: LinkedEventCard.Details? { card.details }
    private var domain: String { card.event.domain }
    private var fill: Color { EntityPresentation.tint(domain: domain) }
    private var ink: Color { Color.domainInk(for: domain) ?? .primary }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous) }

    public var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            eyebrow
            switch card.layout {
            case .metric: metric
            case .journey: journey
            case .calendar: calendar
            case .payment: payment
            case .reading: reading
            }
            if let answer = card.answer {
                answerView(answer)
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, minHeight: size == .compact ? 112 : nil, alignment: .topLeading)
        .background(shape.fill(Color.sparkElevated.mix(with: fill, by: 0.09)))
        .overlay {
            if contrast == .increased {
                shape.strokeBorder(Color.primary.opacity(0.35), lineWidth: 1)
            }
        }
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Eyebrow

    private var eyebrow: some View {
        HStack(spacing: SparkSpacing.sm) {
            chip
            Text(card.label)
                .font(SparkTypography.captionStrong)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let time = eyebrowTime {
                Spacer(minLength: SparkSpacing.xs)
                Text(time)
                    .font(SparkTypography.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    /// The glyph in a rounded square of the domain tint (§6); a reading card
    /// shows the publication's initial instead.
    @ViewBuilder
    private var chip: some View {
        let background = RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fill.opacity(0.2))
        if card.layout == .reading, let initial = details?.publication?.first {
            Text(String(initial).uppercased())
                .font(.system(size: chipSize * 0.5, weight: .bold, design: .serif))
                .foregroundStyle(ink)
                .frame(width: chipSize, height: chipSize)
                .background(background)
        } else {
            Image(systemName: glyph)
                .font(.system(size: chipSize * 0.5, weight: .semibold))
                .foregroundStyle(ink)
                .frame(width: chipSize, height: chipSize)
                .background(background)
        }
    }

    private var glyph: String {
        switch card.layout {
        case .journey: "airplane"
        case .calendar: "calendar"
        case .payment: "sterlingsign"
        case .reading: "newspaper.fill"
        case .metric: kind.systemImage(domain: domain)
        }
    }

    private var eyebrowTime: String? {
        guard let time = card.event.time else { return nil }
        switch card.layout {
        case .journey, .calendar:
            return Calendar.current.isDateInToday(time) ? "Today" : time.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        case .payment:
            return time.formatted(.dateTime.weekday(.abbreviated).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        case .reading:
            return time.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        case .metric:
            return nil
        }
    }

    // MARK: Metric

    @ViewBuilder
    private var metric: some View {
        if size == .wide {
            HStack(alignment: .center, spacing: SparkSpacing.lg) {
                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    if kind.ringMaximum == nil || card.liveValue == nil {
                        heroValue
                    }
                    if let line = contextLine {
                        contextView(line)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                metricVisual
                    .frame(maxWidth: kind.ringMaximum == nil ? 160 : nil)
            }
        } else {
            Spacer(minLength: 0)
            if kind.ringMaximum == nil || card.liveValue == nil {
                heroValue
            }
            metricVisual
            if let line = contextLine {
                contextView(line)
            }
        }
    }

    private var heroValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xxs) {
            Text(card.heroValue)
                .font(SparkFonts.display(size: heroSize, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.sparkHero(domain: domain))
            if let unit = kind.heroUnit, card.liveValue != nil {
                Text(unit)
                    .font(SparkFonts.display(size: unitSize, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    @ViewBuilder
    private var metricVisual: some View {
        if let maximum = kind.ringMaximum, let live = card.liveValue {
            ScoreRing(
                fraction: drawn ? live / maximum : 0,
                text: card.heroValue,
                tint: fill,
                diameter: 64,
                threshold: 85 / maximum,
                valueColor: Color.sparkHero(domain: domain)
            )
            .accessibilityHidden(true)
            .frame(maxWidth: size == .compact ? .infinity : nil)
        } else if let fraction = card.meanBarFraction {
            MeanBar(fraction: drawn ? fraction : 0, fill: fill)
        }
    }

    // MARK: Journey

    private var journey: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(alignment: .center, spacing: SparkSpacing.md) {
                airport(details?.from ?? "", time: clock(details?.departsLocal, details?.departsZone), alignment: .leading)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    RouteLine(progress: drawn ? details?.flightProgress(at: context.date) : nil, fill: fill, ink: ink)
                }
                .frame(height: 18)
                airport(details?.to ?? "", time: clock(details?.arrivesLocal, details?.arrivesZone), alignment: .trailing)
            }
            facts([
                details?.durationMinutes.map { "\(Self.minutes($0)) flight" },
                details?.route,
            ])
        }
    }

    private func airport(_ code: String, time: String?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: SparkSpacing.xs) {
            Text(code)
                .font(SparkFonts.display(size: airportSize, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize()
            if let time {
                Text(time)
                    .font(SparkTypography.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    private func clock(_ time: String?, _ zone: String?) -> String? {
        guard let time else { return nil }
        return [time, zone].compactMap { $0 }.joined(separator: " ")
    }

    // MARK: Calendar

    private var calendar: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text(details?.title ?? "Calendar entry")
                .font(SparkTypography.bodyStrong)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if details?.allDay == true {
                facts(["All day"])
            } else {
                facts([
                    [details?.startsAt, details?.endsAt]
                        .compactMap { $0?.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)) }
                        .joined(separator: " to "),
                    details?.durationMinutes.map(Self.minutes),
                ])
            }
        }
    }

    // MARK: Payment

    private var payment: some View {
        HStack(alignment: .bottom, spacing: SparkSpacing.lg) {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                Text(card.heroValue)
                    .font(SparkFonts.display(size: heroSize, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.sparkHero(domain: domain))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let merchant = details?.merchant {
                    Text(merchant)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                HStack(spacing: SparkSpacing.sm) {
                    if let account = details?.account {
                        Text(account)
                            .font(SparkTypography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if details?.pending == true {
                        Text("Pending")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let week = details?.week, !week.amounts.isEmpty {
                WeekStrip(week: week, fill: fill, drawn: drawn)
            }
        }
    }

    // MARK: Reading

    private var reading: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text(details?.headline ?? "Article")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let minutes = details?.readMinutes {
                facts(["\(minutes) min read"])
            }
            if let takeaways = details?.takeaways, !takeaways.isEmpty {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    ForEach(Array(takeaways.prefix(4).enumerated()), id: \.offset) { _, takeaway in
                        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(fill)
                                .frame(width: 6, height: 6)
                                .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 3 }
                            Text(Self.inline(takeaway))
                                .font(SparkTypography.bodySmall)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.top, SparkSpacing.sm)
                .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1) }
            }
        }
    }

    // MARK: Shared pieces

    private func facts(_ items: [String?]) -> some View {
        HStack(spacing: SparkSpacing.md) {
            ForEach(Array(items.compactMap { $0 }.filter { !$0.isEmpty }.enumerated()), id: \.offset) { _, item in
                Text(item)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func answerView(_ answer: LinkedEventCard.Answer) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sparkSuccess)
            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                Text("You answered")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(answer.text)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, SparkSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1) }
    }

    private struct ContextLine {
        let text: String
        let systemImage: String
        let tint: Color
    }

    private var contextLine: ContextLine? {
        if let updated = card.updatedFromText {
            return ContextLine(text: updated, systemImage: "clock.arrow.circlepath", tint: .secondary)
        }
        guard let context = card.context else { return nil }

        // §3.4: the arrow always points the way the value moved; only its
        // colour depends on whether that is good, bad or within the usual.
        let systemImage = switch context.direction {
        case .flat: "arrow.right"
        case .up: "arrow.up"
        case .down: "arrow.down"
        }
        let tint: Color = switch context.valence {
        case .good: .sparkSuccess
        case .bad: .sparkError
        case .neutral: .secondary
        }
        return ContextLine(text: context.text, systemImage: systemImage, tint: tint)
    }

    private func contextView(_ line: ContextLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xxs) {
            Image(systemName: line.systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(line.tint)
            Text(line.text)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "4h15m", "45m" or "2h".
    static func minutes(_ total: Int) -> String {
        let hours = total / 60
        let rest = total % 60
        if hours == 0 { return "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h\(rest)m"
    }

    /// A takeaway's inline Markdown (its bold lead), or the text as written
    /// when it doesn't parse.
    static func inline(_ markdown: String) -> AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(markdown)
    }

    /// One VoiceOver element: "Sleep score, 66 out of 100, 12 below 30d trend".
    /// Scores carry "out of 100" here and nowhere else (§9).
    private var accessibilityText: String {
        var parts: [String?] = [card.label]
        switch card.layout {
        case .metric:
            if let maximum = kind.ringMaximum, card.liveValue != nil {
                parts.append("\(card.heroValue) out of \(Int(maximum))")
            } else {
                parts.append([card.heroValue, card.liveValue == nil ? nil : kind.heroUnit].compactMap { $0 }.joined(separator: " "))
            }
            parts.append(contextLine?.text)
            if card.meanBarFraction != nil, let mean = card.context?.mean {
                parts.append("30-day average \(kind.heroValue(mean, unit: card.event.unit, displayValue: nil))")
            }
        case .journey:
            parts.append([details?.from, details?.to].compactMap { $0 }.joined(separator: " to "))
            parts.append(details?.departsLocal.map { "departs \($0)" })
            parts.append(details?.arrivesLocal.map { "arrives \($0)" })
            parts.append(details?.durationMinutes.map { "\(Self.minutes($0)) flight" })
        case .calendar:
            parts.append(details?.title)
            parts.append(details?.startsAt?.formatted(date: .omitted, time: .shortened))
        case .payment:
            parts.append(card.heroValue)
            parts.append(details?.merchant)
            parts.append(details?.pending == true ? "pending" : nil)
            parts.append(details?.week?.caption)
        case .reading:
            parts.append(details?.headline)
            parts.append(details?.readMinutes.map { "\($0) minute read" })
            if let takeaways = details?.takeaways, !takeaways.isEmpty {
                parts.append("Takeaways: " + takeaways.prefix(4).map { String(Self.inline($0).characters) }.joined(separator: ". "))
            }
        }
        if let answer = card.answer {
            parts.append("You answered \(answer.text)")
        }
        return parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// The dotted route between two airports, with the plane at the share of
/// the flight gone while it is in the air, and at the middle otherwise.
struct RouteLine: View {
    let progress: Double?
    let fill: Color
    let ink: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let share = progress ?? 0.5
            let y = proxy.size.height / 2
            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            .stroke(fill.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.1, 5]))
            if let progress {
                Capsule()
                    .fill(fill)
                    .frame(width: max(0, width * progress), height: 2)
                    .position(x: width * progress / 2, y: y)
            }
            Image(systemName: "airplane")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ink)
                .position(x: min(max(width * share, 8), width - 8), y: y)
        }
        .accessibilityHidden(true)
    }
}

/// This payment among the week's spending: one bar per payment in time
/// order, this one in the domain fill, with a caption when it stands out.
struct WeekStrip: View {
    let week: LinkedEventCard.Week
    let fill: Color
    let drawn: Bool

    private static let height: CGFloat = 40

    var body: some View {
        let largest = max(week.amounts.max() ?? 1, 1)
        VStack(alignment: .trailing, spacing: SparkSpacing.xs) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(week.amounts.enumerated()), id: \.offset) { index, amount in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index == week.index ? fill : Color.primary.opacity(0.1))
                        .frame(width: 7, height: drawn ? max(4, Self.height * amount / largest) : 4)
                }
            }
            .frame(height: Self.height, alignment: .bottom)
            if let caption = week.caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .accessibilityHidden(true)
    }
}

/// A value against the reader's 30d average (design language §8): a thin
/// track that runs to 1.5× the mean, with a vertical Avg marker at the mean.
struct MeanBar: View {
    let fraction: Double
    let fill: Color

    /// Label on top, then the marker standing 6pt proud of the track.
    private static let barHeight: CGFloat = 6
    private static let barTop: CGFloat = 18
    private static let markerTop: CGFloat = 12
    private static let totalHeight: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let markerX = width * LinkedEventCard.meanBarMarker
            let barY = Self.barTop + Self.barHeight / 2

            Capsule()
                .fill(Color.primary.opacity(0.1))
                .frame(width: width, height: Self.barHeight)
                .position(x: width / 2, y: barY)
            Capsule()
                .fill(fill)
                .frame(width: max(Self.barHeight, width * fraction), height: Self.barHeight)
                .position(x: max(Self.barHeight, width * fraction) / 2, y: barY)
            Capsule()
                .fill(Color.primary)
                .frame(width: 2, height: Self.totalHeight - Self.markerTop)
                .position(x: markerX, y: (Self.markerTop + Self.totalHeight) / 2)
            Text("Avg")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
                .position(x: markerX, y: Self.markerTop / 2)
        }
        .frame(height: Self.totalHeight)
        .accessibilityHidden(true)
    }
}

/// The cards under a paragraph, in the order the prose mentions them
/// (design language §7.3).
///
/// Metric cards go two or three across, with "+N more" in the third slot
/// past three; a lone metric card takes the row. Flights, calendar entries,
/// payments and articles always take a row each. When the row first appears
/// the cards rise in 70ms apart and their rings, bars and routes draw once;
/// under Reduce Motion they are simply there. Tapping a card gives a light
/// haptic and opens its event.
public struct EventCardRow: View {
    let cards: [LinkedEventCard]
    let onOpen: (LinkedEventCard) -> Void

    @State private var isExpanded = false
    @State private var hasAppeared = false
    @State private var tapped = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ cards: [LinkedEventCard], onOpen: @escaping (LinkedEventCard) -> Void) {
        self.cards = cards
        self.onOpen = onOpen
    }

    /// Runs of metric cards share a grid; every other card is its own run.
    private enum Run: Identifiable {
        case grid([LinkedEventCard])
        case wide(LinkedEventCard)

        var id: String {
            switch self {
            case .grid(let cards): "grid-" + cards.map(\.id).joined(separator: "-")
            case .wide(let card): "wide-" + card.id
            }
        }
    }

    private var runs: [Run] {
        var runs: [Run] = []
        var metrics: [LinkedEventCard] = []
        for card in cards {
            if card.layout.isWide {
                if !metrics.isEmpty { runs.append(.grid(metrics)); metrics = [] }
                runs.append(.wide(card))
            } else {
                metrics.append(card)
            }
        }
        if !metrics.isEmpty { runs.append(.grid(metrics)) }
        return runs
    }

    private var isDrawn: Bool { hasAppeared || reduceMotion }

    public var body: some View {
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                ForEach(runs) { run in
                    switch run {
                    case .wide(let card):
                        cardButton(card, size: .wide)
                    case .grid(let metrics):
                        MetricCardGrid(
                            cards: metrics,
                            isExpanded: $isExpanded,
                            columns: dynamicTypeSize.isAccessibilitySize ? 1 : min(3, metrics.count)
                        ) { card in
                            cardButton(card, size: metrics.count == 1 ? .wide : .compact)
                        }
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: tapped)
            .onAppear {
                guard !hasAppeared else { return }
                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.spring(duration: 0.9, bounce: 0.1).delay(0.15)) { hasAppeared = true }
                }
            }
        }
    }

    private func cardButton(_ card: LinkedEventCard, size: EventCard.Size) -> some View {
        let order = Double(cards.firstIndex(of: card) ?? 0)
        return Button {
            tapped += 1
            onOpen(card)
        } label: {
            EventCard(card, size: size, drawn: isDrawn)
        }
        .buttonStyle(.plain)
        .opacity(isDrawn ? 1 : 0)
        .offset(y: isDrawn ? 0 : 10)
        .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.15).delay(0.07 * order), value: isDrawn)
    }
}

/// Metric cards two or three across; past three, the third slot reads
/// "+N more" and reveals the rest. One column at accessibility text sizes,
/// where each card grows to fit its text (§11).
private struct MetricCardGrid<Card: View>: View {
    let cards: [LinkedEventCard]
    @Binding var isExpanded: Bool
    let columns: Int
    @ViewBuilder let card: (LinkedEventCard) -> Card

    private var visible: [LinkedEventCard] {
        isExpanded || cards.count <= 3 ? cards : Array(cards.prefix(2))
    }

    private var hiddenCount: Int { cards.count - visible.count }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: SparkSpacing.md, alignment: .top), count: max(1, columns)),
            spacing: SparkSpacing.md
        ) {
            ForEach(visible) { item in
                card(item)
            }
            if hiddenCount > 0 {
                Button { isExpanded = true } label: {
                    Text("+\(hiddenCount) more")
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 112)
                        .background(
                            RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous)
                                .fill(Color.sparkElevated)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows the other linked events")
            }
        }
    }
}
