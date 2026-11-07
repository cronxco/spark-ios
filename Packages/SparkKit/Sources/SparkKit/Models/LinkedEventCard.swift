import Foundation

/// An event a Flint digest's prose links to, shaped as a card.
///
/// Flint writes each number it quotes as a link to its event ("a [sleep
/// score of 66](https://spark.cronx.co/events/…)"). The backend resolves
/// those links into `linked_events` on the Up to Speed digest payload, and
/// each briefing paragraph shows cards for the events it links to.
/// Mirrors `FlintLinkedEventCards` on the backend.
public struct LinkedEventCard: Codable, Sendable, Hashable, Identifiable {
    /// `{service}.{action}`; see `EventKind`.
    public let kindKey: String
    /// The live event. Its value can differ from what the prose says.
    public let event: Event
    public let context: Context?
    /// What the digest quoted, when the event has changed since it was
    /// written. Cards show the live value and say "Updated from …".
    public let atDigest: AtDigest?

    /// Which card this event gets (design language §7.3). Daily metrics keep
    /// the compact metric card; one-off events get a card that says what
    /// they are. Unknown layouts from a newer backend fall back to `.metric`.
    public let layout: Layout
    /// The facts the layout shows; `nil` for `.metric`.
    public let details: Details?
    /// The reader's answer to a Flint question in the same digest that links
    /// this event.
    public let answer: Answer?

    public var id: String { event.id }
    public var kind: EventKind { EventKind(kindKey) }

    public enum Layout: String, Codable, Sendable, Hashable {
        case metric, journey, calendar, payment, transfer, reading, digest

        /// Every layout but a metric takes the whole row.
        public var isWide: Bool { self != .metric }
    }

    /// Layout-specific facts, decoded flat: each layout fills its own keys
    /// and leaves the rest `nil`. Instants stay ISO 8601 strings so a cached
    /// payload round-trips whatever date strategy decoded it.
    public struct Details: Codable, Sendable, Hashable {
        // Journey
        public let flight: String?
        public let from: String?
        public let to: String?
        public let route: String?
        public let departsAtText: String?
        public let arrivesAtText: String?
        public let departsLocal: String?
        public let departsZone: String?
        public let arrivesLocal: String?
        public let arrivesZone: String?
        public let durationMinutes: Int?
        // Calendar
        public let title: String?
        public let startsAtText: String?
        public let endsAtText: String?
        public let allDay: Bool?
        // Payment
        public let merchant: String?
        public let account: String?
        public let pending: Bool?
        public let refund: Bool?
        public let week: Week?
        // Transfer (account and pending are shared with Payment)
        /// `in` or `out`.
        public let direction: String?
        /// The other party in display case: a pot, a person, or the bank
        /// reference ("Mortgage").
        public let counterparty: String?
        // Reading
        public let publication: String?
        public let headline: String?
        public let url: String?
        public let readMinutes: Int?
        public let takeaways: [String]?
        // Digest
        public let name: String?
        public let facts: [String]?
        public let items: [DigestItem]?

        enum CodingKeys: String, CodingKey {
            case flight, from, to, route, title, merchant, account, pending, refund, week, direction, counterparty, publication, headline, url, takeaways
            case name, facts, items
            case departsAtText = "departs_at"
            case arrivesAtText = "arrives_at"
            case departsLocal = "departs_local"
            case departsZone = "departs_zone"
            case arrivesLocal = "arrives_local"
            case arrivesZone = "arrives_zone"
            case durationMinutes = "duration_minutes"
            case startsAtText = "starts_at"
            case endsAtText = "ends_at"
            case allDay = "all_day"
            case readMinutes = "read_minutes"
        }

        public init(
            flight: String? = nil, from: String? = nil, to: String? = nil, route: String? = nil,
            departsAtText: String? = nil, arrivesAtText: String? = nil,
            departsLocal: String? = nil, departsZone: String? = nil, arrivesLocal: String? = nil, arrivesZone: String? = nil,
            durationMinutes: Int? = nil,
            title: String? = nil, startsAtText: String? = nil, endsAtText: String? = nil, allDay: Bool? = nil,
            merchant: String? = nil, account: String? = nil, pending: Bool? = nil, refund: Bool? = nil, week: Week? = nil,
            direction: String? = nil, counterparty: String? = nil,
            publication: String? = nil, headline: String? = nil, url: String? = nil, readMinutes: Int? = nil, takeaways: [String]? = nil,
            name: String? = nil, facts: [String]? = nil, items: [DigestItem]? = nil
        ) {
            self.flight = flight
            self.from = from
            self.to = to
            self.route = route
            self.departsAtText = departsAtText
            self.arrivesAtText = arrivesAtText
            self.departsLocal = departsLocal
            self.departsZone = departsZone
            self.arrivesLocal = arrivesLocal
            self.arrivesZone = arrivesZone
            self.durationMinutes = durationMinutes
            self.title = title
            self.startsAtText = startsAtText
            self.endsAtText = endsAtText
            self.allDay = allDay
            self.merchant = merchant
            self.account = account
            self.pending = pending
            self.refund = refund
            self.week = week
            self.direction = direction
            self.counterparty = counterparty
            self.publication = publication
            self.headline = headline
            self.url = url
            self.readMinutes = readMinutes
            self.takeaways = takeaways
            self.name = name
            self.facts = facts
            self.items = items
        }

        /// Money going out of the reader's account.
        public var isOutgoing: Bool { direction == "out" }

        /// "into Current Account", or "from Current Account" for money going
        /// out; read after the counterparty in bold (Will, 6 Nov 2026).
        public var transferAccountText: String? {
            guard let account, !account.isEmpty else { return nil }
            return isOutgoing ? "from \(account)" : "into \(account)"
        }

        public var departsAt: Date? { departsAtText.flatMap(Self.instant) }
        public var arrivesAt: Date? { arrivesAtText.flatMap(Self.instant) }
        public var startsAt: Date? { startsAtText.flatMap(Self.instant) }
        public var endsAt: Date? { endsAtText.flatMap(Self.instant) }

        /// How far through the flight `now` is, 0...1; `nil` before
        /// departure, after arrival or without both times.
        public func flightProgress(at now: Date) -> Double? {
            guard let departsAt, let arrivesAt, arrivesAt > departsAt, now > departsAt, now < arrivesAt else { return nil }
            return now.timeIntervalSince(departsAt) / arrivesAt.timeIntervalSince(departsAt)
        }

        private static func instant(_ text: String) -> Date? {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: text)
        }
    }

    /// One story or pick in a Flint digest: its headline, the outlets that
    /// covered a story, and a reading pick's read time.
    public struct DigestItem: Codable, Sendable, Hashable {
        public let title: String
        public let sources: [String]
        public let readMinutes: Int?

        enum CodingKeys: String, CodingKey {
            case title, sources
            case readMinutes = "read_minutes"
        }

        public init(title: String, sources: [String] = [], readMinutes: Int? = nil) {
            self.title = title
            self.sources = sources
            self.readMinutes = readMinutes
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try c.decode(String.self, forKey: .title)
            sources = (try? c.decodeIfPresent([String].self, forKey: .sources)) ?? []
            readMinutes = try? c.decodeIfPresent(Int.self, forKey: .readMinutes)
        }
    }

    /// This payment among the week's spending: amounts in pence in time
    /// order, which bar is this payment, and a caption when it stands out.
    public struct Week: Codable, Sendable, Hashable {
        public let amounts: [Double]
        public let index: Int
        public let caption: String?

        public init(amounts: [Double], index: Int, caption: String?) {
            self.amounts = amounts
            self.index = index
            self.caption = caption
        }
    }

    public struct Answer: Codable, Sendable, Hashable {
        public let answer: String
        public let note: String?

        public init(answer: String, note: String?) {
            self.answer = answer
            self.note = note
        }

        /// The note when the reader wrote one, which says more than the
        /// option they picked.
        public var text: String {
            guard let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return answer }
            return note
        }
    }

    /// One line comparing the live value with the reader's 30d baseline:
    /// "12 below 30d trend", or "35m above 30d avg" for kinds drawn against
    /// the mean.
    public struct Context: Codable, Sendable, Hashable {
        public enum Direction: String, Codable, Sendable, Hashable {
            case up, down, flat
        }

        public let direction: Direction
        public let valence: AnomalyValence
        public let withinUsualRange: Bool
        public let text: String
        /// The 30d average, in the event's own unit.
        public let mean: Double?

        enum CodingKeys: String, CodingKey {
            case direction, valence, text, mean
            case withinUsualRange = "within_usual_range"
        }

        public init(direction: Direction, valence: AnomalyValence, withinUsualRange: Bool, text: String, mean: Double? = nil) {
            self.direction = direction
            self.valence = valence
            self.withinUsualRange = withinUsualRange
            self.text = text
            self.mean = mean
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            direction = (try? c.decode(Direction.self, forKey: .direction)) ?? .flat
            valence = (try? c.decode(AnomalyValence.self, forKey: .valence)) ?? .neutral
            withinUsualRange = try c.decodeIfPresent(Bool.self, forKey: .withinUsualRange) ?? true
            text = try c.decode(String.self, forKey: .text)
            mean = try? c.decodeIfPresent(Double.self, forKey: .mean)
        }
    }

    public struct AtDigest: Codable, Sendable, Hashable {
        public let value: Double?
        public let displayValue: String?

        enum CodingKeys: String, CodingKey {
            case value
            case displayValue = "display_value"
        }

        public init(value: Double?, displayValue: String?) {
            self.value = value
            self.displayValue = displayValue
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let number = try? c.decodeIfPresent(Double.self, forKey: .value) {
                value = number
            } else if let text = try? c.decodeIfPresent(String.self, forKey: .value) {
                value = Double(text)
            } else {
                value = nil
            }
            displayValue = try c.decodeIfPresent(String.self, forKey: .displayValue)
        }
    }

    enum CodingKeys: String, CodingKey {
        case event, context, layout, details, answer
        case kindKey = "kind"
        case atDigest = "at_digest"
    }

    public init(
        kindKey: String,
        event: Event,
        context: Context? = nil,
        atDigest: AtDigest? = nil,
        layout: Layout = .metric,
        details: Details? = nil,
        answer: Answer? = nil
    ) {
        self.kindKey = kindKey
        self.event = event
        self.context = context
        self.atDigest = atDigest
        self.layout = layout
        self.details = details
        self.answer = answer
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        event = try c.decode(Event.self, forKey: .event)
        kindKey = try c.decodeIfPresent(String.self, forKey: .kindKey) ?? "\(event.service).\(event.action)"
        context = try? c.decodeIfPresent(Context.self, forKey: .context)
        atDigest = try? c.decodeIfPresent(AtDigest.self, forKey: .atDigest)
        layout = (try? c.decodeIfPresent(String.self, forKey: .layout)).flatMap(Layout.init(rawValue:)) ?? .metric
        details = try? c.decodeIfPresent(Details.self, forKey: .details)
        answer = try? c.decodeIfPresent(Answer.self, forKey: .answer)
    }

    /// The live value as a number, if the event has one.
    public var liveValue: Double? {
        event.value.flatMap { Double($0) }
    }

    public var heroValue: String {
        kind.heroValue(liveValue, unit: event.unit, displayValue: event.displayValue)
    }

    /// How far along the against-the-mean bar the live value sits. The
    /// track runs to 1.5× the 30d average, so the Avg marker is at
    /// `meanBarMarker`. `nil` when the kind has no bar or there is no mean.
    public var meanBarFraction: Double? {
        guard kind.drawsAgainstMean, let live = liveValue, let mean = context?.mean, mean > 0 else { return nil }
        return min(max(live / (mean * Self.meanBarSpan), 0), 1)
    }

    public static let meanBarSpan = 1.5
    public static let meanBarMarker = 1 / meanBarSpan

    /// "Updated from 66", in the kind's own format.
    public var updatedFromText: String? {
        guard let atDigest else { return nil }
        return "Updated from \(kind.heroValue(atDigest.value, unit: event.unit, displayValue: atDigest.displayValue))"
    }

    /// The eyebrow label: the kind's short label, else the action's own
    /// display name from the backend.
    public var label: String {
        switch layout {
        case .journey: details?.flight.map { "Flight \($0)" } ?? "Flight"
        case .calendar: "Calendar"
        case .payment: details?.refund == true ? "Refund" : "Payment"
        case .transfer: details?.isOutgoing == true ? "Transfer out" : "Transfer in"
        case .reading: details?.publication ?? "Article"
        case .digest: details?.name ?? "Digest"
        case .metric: kind.shortLabel ?? event.displayName ?? "Event"
        }
    }

    // MARK: - Linking prose to cards

    private static let linkPattern =
        "/events?/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})(?![0-9a-z-])"

    /// Event ids linked from a stretch of Markdown, in the order they are
    /// first mentioned. Matches `FlintLinkedEventCards::linkedIds`.
    public static func linkedEventIDs(in markdown: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(markdown.startIndex..., in: markdown)
        var seen = Set<String>()
        return expression.matches(in: markdown, range: range).compactMap { match in
            guard let idRange = Range(match.range(at: 1), in: markdown) else { return nil }
            let id = markdown[idRange].lowercased()
            return seen.insert(id).inserted ? id : nil
        }
    }

    /// The cards a paragraph links to, in its own order.
    public static func cards(linkedFrom markdown: String, in cards: [LinkedEventCard]) -> [LinkedEventCard] {
        let byID = Dictionary(cards.map { ($0.event.id.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        return linkedEventIDs(in: markdown).compactMap { byID[$0] }
    }
}
