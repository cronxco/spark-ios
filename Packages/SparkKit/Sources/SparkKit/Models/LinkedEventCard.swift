import Foundation

/// A metric event a Flint digest's prose links to, shaped as a card.
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

    public var id: String { event.id }
    public var kind: EventKind { EventKind(kindKey) }

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
        case event, context
        case kindKey = "kind"
        case atDigest = "at_digest"
    }

    public init(kindKey: String, event: Event, context: Context? = nil, atDigest: AtDigest? = nil) {
        self.kindKey = kindKey
        self.event = event
        self.context = context
        self.atDigest = atDigest
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        event = try c.decode(Event.self, forKey: .event)
        kindKey = try c.decodeIfPresent(String.self, forKey: .kindKey) ?? "\(event.service).\(event.action)"
        context = try? c.decodeIfPresent(Context.self, forKey: .context)
        atDigest = try? c.decodeIfPresent(AtDigest.self, forKey: .atDigest)
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
        kind.shortLabel ?? event.displayName ?? "Event"
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
